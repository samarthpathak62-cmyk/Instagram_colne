import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/loading_indicator.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import '../widgets/feed_item_card.dart';
import '../widgets/feed_refresh_indicator.dart';
import '../widgets/feed_stories_bar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Initial load of feed posts
    context.read<FeedBloc>().add(const LoadFeed(page: 0));
  }

  void _onScroll() {
    final bloc = context.read<FeedBloc>();
    final state = bloc.state;
    if (_isBottom &&
        state is FeedLoaded &&
        !state.hasReachedMax &&
        state.feedItems.length >= _pageSize) {
      bloc.add(LoadFeed(
          page: state.feedItems.length ~/ _pageSize, limit: _pageSize));
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9); // Load more when 90% scrolled
  }

  Future<void> _onRefresh() async {
    context.read<FeedBloc>().add(const RefreshFeedEvent());
    // Wait for the bloc to emit a new state
    await BlocProvider.of<FeedBloc>(context)
        .stream
        .firstWhere((state) => state is! FeedLoading);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FeedRefreshIndicator(
            onRefresh: _onRefresh,
            child: BlocBuilder<FeedBloc, FeedState>(
              builder: (context, state) {
                return CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Card(
                        margin: const EdgeInsets.only(top: 16, bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(start: 8),
                                child: Text('Stories',
                                    style: context.veyroText.titleMedium),
                              ),
                              const SizedBox(height: 9),
                              const FeedStoriesBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (state is FeedError)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: CustomErrorWidget(
                          message: state.message,
                          onRetry: () => context
                              .read<FeedBloc>()
                              .add(const LoadFeed(page: 0)),
                        ),
                      )
                    else if (state is FeedLoaded && state.feedItems.isEmpty)
                      SliverToBoxAdapter(child: _buildEmptyFeedState(context))
                    else if (state is FeedLoaded)
                      SliverList.builder(
                        itemCount: state.feedItems.length +
                            (state.hasReachedMax ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index == state.feedItems.length) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: LoadingIndicator(),
                            );
                          }
                          return FeedItemCard(
                            feedItem: state.feedItems[index],
                            onPostTap: (postId) {
                              Navigator.of(context)
                                  .push(MaterialPageRoute<void>(
                                builder: (_) =>
                                    PostDetailScreen(postId: postId),
                              ));
                            },
                            onLikeToggle: (postId, isLiked, likesCount) {
                              final auth = context.read<AuthBloc>().state;
                              if (auth is! Authenticated) return;
                              context
                                  .read<FeedBloc>()
                                  .add(UpdateFeedPostLikeStatus(
                                    postId: postId,
                                    userId: auth.user.id,
                                    isLiked: isLiked,
                                    likesCount: likesCount,
                                  ));
                            },
                          );
                        },
                      )
                    else
                      const SliverFillRemaining(
                          hasScrollBody: false, child: LoadingIndicator()),
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

  Widget _buildEmptyFeedState(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 8),
        clipBehavior: Clip.antiAlias,
        child: VeyroAtmosphere(
          rings: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 27),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VeyroMark(size: 110),
                Text(
                  'Welcome to Veyro',
                  textAlign: TextAlign.center,
                  style: context.veyroText.headlineMedium?.copyWith(
                    color: VeyroTheme.frost,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Follow people to see their photos and videos here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD5C6E8), height: 1.55),
                ),
                const SizedBox(height: 22),
                Center(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const SearchScreen(),
                    )),
                    icon: const Icon(Icons.search_rounded, size: 19),
                    label: const Text('Find people'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
