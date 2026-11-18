import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/loading_indicator.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_state.dart';
import 'package:instagram_clone/features/feed/presentation/widgets/feed_stories_bar.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback onCompose;

  const FeedScreen({super.key, required this.onCompose});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_requestMore);
  }

  void _requestMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 350) {
      context.read<FeedCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.read<FeedCubit>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RefreshIndicator(
            onRefresh: feed.refresh,
            child: BlocBuilder<FeedCubit, FeedState>(
              builder: (context, state) {
                final local = context.watch<PostInteractionsCubit>().state;
                final visible = state.items
                    .where((item) => local[item.id]?.deleted != true)
                    .toList();
                return CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _feedHeader(context, state)),
                    if (visible.isEmpty && state.loading)
                      const SliverFillRemaining(
                          hasScrollBody: false, child: LoadingIndicator())
                    else if (visible.isEmpty && state.error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: CustomErrorWidget(
                            message: state.error!, onRetry: feed.refresh),
                      )
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(
                          child: _emptyFeed(context, state.timeline))
                    else ...[
                      SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) => PostCard(
                          key: ValueKey(visible[index].id),
                          post: visible[index].toPost(),
                        ),
                      ),
                      if (state.loading)
                        const SliverToBoxAdapter(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: LoadingIndicator()))
                      else if (state.error != null || state.hasMore)
                        SliverToBoxAdapter(
                          child: Center(
                              child: TextButton.icon(
                            onPressed: () => feed.loadMore(retry: true),
                            icon: const Icon(Icons.expand_more_rounded),
                            label: Text(state.error == null
                                ? 'Load more posts'
                                : 'Retry loading more posts'),
                          )),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedHeader(BuildContext context, FeedState state) {
    final auth = context.watch<AuthBloc>().state;
    final feed = context.read<FeedCubit>();
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Text('Stories', style: context.veyroText.titleMedium),
                ),
                const SizedBox(height: 9),
                const FeedStoriesBar(),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 7),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            leading: UserAvatar(
                imageUrl:
                    auth is Authenticated ? auth.user.profileImageUrl : null),
            title: const Text('What’s on your mind?'),
            trailing: const Icon(Icons.edit_square, size: 21),
            onTap: widget.onCompose,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final timeline in FeedTimeline.values)
                      ChoiceChip(
                        label: Text(timeline == FeedTimeline.latest
                            ? 'Latest'
                            : 'Following'),
                        selected: timeline == state.timeline,
                        onSelected: (_) => feed.selectTimeline(timeline),
                      ),
                  ],
                ),
              ),
              IconButton(
                  tooltip: 'Refresh feed',
                  onPressed: feed.refresh,
                  icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyFeed(BuildContext context, FeedTimeline timeline) => Card(
        margin: const EdgeInsets.only(top: 8),
        clipBehavior: Clip.antiAlias,
        child: VeyroAtmosphere(
          rings: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VeyroMark(size: 100),
                Text(
                  timeline == FeedTimeline.latest
                      ? 'Welcome to Veyro'
                      : 'Your Following feed',
                  textAlign: TextAlign.center,
                  style: context.veyroText.headlineMedium
                      ?.copyWith(color: VeyroTheme.frost, fontSize: 25),
                ),
                const SizedBox(height: 8),
                Text(
                  timeline == FeedTimeline.latest
                      ? 'Start the conversation or find someone to follow.'
                      : 'Updates from you and the people you follow will appear here.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFFD5C6E8), height: 1.55),
                ),
                const SizedBox(height: 20),
                Center(
                    child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              const SearchScreen(startWithPeople: true))),
                  icon: const Icon(Icons.search_rounded, size: 19),
                  label: const Text('Find people'),
                )),
              ],
            ),
          ),
        ),
      );
}
