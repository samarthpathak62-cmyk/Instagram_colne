import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/loading_indicator.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
import 'package:instagram_clone/features/explore/domain/post_topics.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_state.dart';
import 'package:instagram_clone/features/feed/presentation/widgets/feed_stories_bar.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';

enum FeedComposeMode { post, photo, reel }

class FeedScreen extends StatefulWidget {
  final ValueChanged<FeedComposeMode> onCompose;

  final VoidCallback onGroups;

  const FeedScreen(
      {super.key, required this.onCompose, required this.onGroups});

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

  void _browse({String topic = '', bool people = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            SearchScreen(initialQuery: topic, startWithPeople: people)));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 914 : 602),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 19 : 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _timeline(wide: wide)),
                      if (wide) ...[
                        const SizedBox(width: 27),
                        SizedBox(width: 264, child: _discoveryPanel()),
                      ],
                    ]),
              ),
            ),
          );
        },
      );

  Widget _timeline({required bool wide}) {
    final feed = context.read<FeedCubit>();
    return RefreshIndicator(
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
              SliverToBoxAdapter(
                  child: _feedHeader(context, state, wide: wide)),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: state.loading
                      ? const Padding(
                          padding: EdgeInsets.all(30),
                          child: LoadingIndicator())
                      : _feedStatus(state),
                )
              else ...[
                SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) => PostCard(
                    key: ValueKey(visible[index].id),
                    post: visible[index].toPost(),
                  ),
                ),
                if (state.loading && !state.refreshing)
                  const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: LoadingIndicator()))
                else if (!state.loading &&
                    (state.error != null || state.hasMore))
                  SliverToBoxAdapter(
                    child: Center(
                        child: TextButton.icon(
                      onPressed:
                          state.error == null ? feed.loadMore : feed.refresh,
                      icon: Icon(state.error == null
                          ? Icons.expand_more_rounded
                          : Icons.refresh_rounded),
                      label: Text(state.error == null
                          ? 'Load more posts'
                          : 'Retry loading posts'),
                    )),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _feedHeader(BuildContext context, FeedState state,
      {required bool wide}) {
    final colors = context.veyroColors;
    final feed = context.read<FeedCubit>();
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (wide) ...[
        const SizedBox(height: 27),
        const VeyroEyebrow('In your orbit'),
        const SizedBox(height: 4),
        Text('Your feed', style: context.veyroText.headlineMedium),
        const SizedBox(height: 15),
      ] else
        const SizedBox(height: 13),
      Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(5, 0, 5, 5),
          child: Row(children: [
            Expanded(
                child: Text('Stories',
                    style: context.veyroText.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800))),
            Text('24 hours', style: context.veyroText.bodySmall),
          ])),
      FeedStoriesBar(onDiscover: () => _browse(people: true)),
      const SizedBox(height: 8),
      Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 5, 5),
            child: Row(children: [
              UserAvatar(
                  imageUrl: user?.profilePictureUrl,
                  name: user?.name ?? user?.username,
                  radius: 17),
              const SizedBox(width: 7),
              Expanded(
                  child: TextButton(
                      onPressed: () => widget.onCompose(FeedComposeMode.post),
                      style: TextButton.styleFrom(
                          alignment: AlignmentDirectional.centerStart,
                          foregroundColor: colors.onSurfaceVariant,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          textStyle: context.veyroText.bodyMedium),
                      child: const Text('What’s on your mind?',
                          maxLines: 1, overflow: TextOverflow.ellipsis))),
              IconButton(
                  tooltip: 'Photo',
                  onPressed: () => widget.onCompose(FeedComposeMode.photo),
                  color: colors.primary,
                  icon: const Icon(Icons.photo_library_outlined, size: 21)),
              IconButton(
                  tooltip: 'Reel',
                  onPressed: () => widget.onCompose(FeedComposeMode.reel),
                  color: colors.primary,
                  icon: const Icon(Icons.movie_outlined, size: 22)),
            ]),
          )),
      const SizedBox(height: 7),
      Row(children: [
        Expanded(
            child: Wrap(spacing: 7, runSpacing: 2, children: [
          for (final timeline in FeedTimeline.values)
            ChoiceChip(
              showCheckmark: false,
              label: Text(
                  timeline == FeedTimeline.latest ? 'Latest' : 'Following'),
              labelStyle: context.veyroText.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: timeline == state.timeline
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant),
              selected: timeline == state.timeline,
              onSelected: (_) => feed.selectTimeline(timeline),
            ),
        ])),
        IconButton(
            tooltip: 'Refresh feed',
            onPressed: feed.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 21)),
      ]),
      if (state.refreshing && state.items.isNotEmpty)
        const LinearProgressIndicator(minHeight: 2),
    ]);
  }

  Widget _feedStatus(FeedState state) {
    final following = state.timeline == FeedTimeline.following;
    final hasError = state.error != null;
    final feed = context.read<FeedCubit>();
    return Card(
        margin: const EdgeInsets.only(top: 7),
        child: VeyroEmptyState(
          icon: hasError
              ? Icons.cloud_off_outlined
              : following
                  ? Icons.group_outlined
                  : Icons.collections_outlined,
          title: hasError
              ? 'Couldn’t load your feed'
              : following
                  ? 'Make this feed yours'
                  : 'It’s quiet here for now',
          description: hasError
              ? 'Check your connection and try again.'
              : following
                  ? 'Your posts and updates from people you follow appear here.'
                  : 'Share your first moment or find people to follow.',
          action: Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 5,
              children: [
                if (hasError)
                  FilledButton(
                      onPressed: feed.refresh, child: const Text('Retry'))
                else
                  FilledButton(
                      onPressed: () => _browse(people: true),
                      child: const Text('Discover people')),
                if (following)
                  TextButton(
                      onPressed: () => feed.selectTimeline(FeedTimeline.latest),
                      child: const Text('See Latest')),
              ]),
        ));
  }

  Widget _discoveryPanel() {
    final theme = Theme.of(context);
    final posts = context.watch<FeedCubit>().state.items;
    final local = context.watch<PostInteractionsCubit>();
    final counts = <String, int>{};
    for (final item in posts) {
      final state = local.forPost(item.id);
      if (state.deleted) continue;
      for (final topic in postTopics(state.description ?? item.caption ?? '')) {
        counts.update(topic, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final topics = counts.entries.toList()
      ..sort((a, b) {
        final popularity = b.value.compareTo(a.value);
        return popularity == 0 ? a.key.compareTo(b.key) : popularity;
      });
    return ListView(
      padding: const EdgeInsets.only(top: 29, bottom: 20),
      children: [
        const VeyroEyebrow('Discover'),
        const SizedBox(height: 10),
        Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              const Positioned.fill(
                  child: ColoredBox(
                      color: VeyroTheme.midnight,
                      child:
                          VeyroOrbitArtwork(alignment: Alignment.topCenter))),
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x93100D17),
                  Color(0xFF100D17)
                ],
                stops: [0, .55, .91],
              )))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 115, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VeyroEyebrow('Communities',
                          color: VeyroTheme.lilac),
                      const SizedBox(height: 5),
                      Text('Find your people',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(color: VeyroTheme.frost)),
                      const SizedBox(height: 5),
                      Text('Make space for what you love.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFDCCDEB))),
                      const SizedBox(height: 13),
                      FilledButton.icon(
                          onPressed: widget.onGroups,
                          icon: const Icon(Icons.groups_outlined, size: 18),
                          label: const Text('Browse groups')),
                    ],
                  )),
            ])),
        const SizedBox(height: 17),
        Text(topics.isNotEmpty ? 'Topics from your feed' : 'Grow your circle',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        if (topics.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final topic in topics.take(6))
              ActionChip(
                  label: Text(topic.key),
                  onPressed: () => _browse(topic: topic.key)),
          ])
        else
          Text('Follow people you enjoy to see more of them in your feed.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.55)),
        const SizedBox(height: 6),
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _browse(people: true),
              icon: const Icon(Icons.person_search_outlined, size: 19),
              label: const Text('Explore people'),
            )),
      ],
    );
  }
}
