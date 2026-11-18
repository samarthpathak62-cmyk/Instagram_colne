import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/loading_indicator.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
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
          final wide = constraints.maxWidth >= 950;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1030 : 670),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _timeline()),
                      if (wide) ...[
                        const SizedBox(width: 24),
                        SizedBox(width: 274, child: _discoveryPanel()),
                      ],
                    ]),
              ),
            ),
          );
        },
      );

  Widget _timeline() {
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
              SliverToBoxAdapter(child: _feedHeader(context, state)),
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

  Widget _feedHeader(BuildContext context, FeedState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feed = context.read<FeedCubit>();
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 15, 8, 10),
        child: Row(children: [
          Expanded(
              child: Text('Stories',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800))),
          Icon(Icons.timelapse_rounded,
              color: colors.onSurfaceVariant, size: 15),
          const SizedBox(width: 4),
          Text('24 hours',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      ),
      const FeedStoriesBar(),
      Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: UserAvatar(
                  imageUrl: user?.profilePictureUrl,
                  name: user?.name ?? user?.username),
              title: Text('What’s on your mind?',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              trailing:
                  Icon(Icons.edit_square, size: 19, color: colors.primary),
              onTap: () => widget.onCompose(FeedComposeMode.post),
            ),
            const Divider(),
            Wrap(alignment: WrapAlignment.spaceAround, children: [
              _composeButton(FeedComposeMode.post, Icons.notes_rounded, 'Text'),
              _composeButton(
                  FeedComposeMode.photo, Icons.photo_outlined, 'Photo'),
              _composeButton(
                  FeedComposeMode.reel, Icons.video_library_outlined, 'Reel'),
            ]),
          ]),
        ),
      ),
      Row(children: [
        Expanded(
          child: Wrap(spacing: 7, runSpacing: 3, children: [
            for (final timeline in FeedTimeline.values)
              ChoiceChip(
                showCheckmark: false,
                label: Text(
                    timeline == FeedTimeline.latest ? 'Latest' : 'Following'),
                selected: timeline == state.timeline,
                onSelected: (_) => feed.selectTimeline(timeline),
              ),
          ]),
        ),
        IconButton(
            tooltip: 'Refresh feed',
            onPressed: feed.refresh,
            icon: const Icon(Icons.refresh_rounded)),
      ]),
      if (state.refreshing && state.items.isNotEmpty)
        const LinearProgressIndicator(minHeight: 2)
      else
        const Divider(height: 2),
    ]);
  }

  Widget _composeButton(FeedComposeMode mode, IconData icon, String label) =>
      TextButton.icon(
        onPressed: () => widget.onCompose(mode),
        style: TextButton.styleFrom(
            foregroundColor: context.veyroColors.onSurfaceVariant),
        icon: Icon(icon, size: 18, color: context.veyroColors.primary),
        label: Text(label),
      );

  Widget _feedStatus(FeedState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final following = state.timeline == FeedTimeline.following;
    final error = state.error;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Icon(error != null
                ? Icons.cloud_off_outlined
                : following
                    ? Icons.group_outlined
                    : Icons.forum_outlined),
          ),
          const SizedBox(height: 10),
          Text(
              error ??
                  (following
                      ? 'Make this feed yours'
                      : 'The conversation starts here'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
              error != null
                  ? 'Check your connection and try again.'
                  : following
                      ? 'Your posts and updates from people you follow appear here.'
                      : 'Share a post or discover someone new on Veyro.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 14),
          Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            if (error != null)
              FilledButton(
                  onPressed: context.read<FeedCubit>().refresh,
                  child: const Text('Retry'))
            else
              FilledButton.icon(
                  onPressed: () => _browse(people: true),
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Find people')),
            if (following)
              TextButton(
                  onPressed: () => context
                      .read<FeedCubit>()
                      .selectTimeline(FeedTimeline.latest),
                  child: const Text('See Latest')),
          ]),
        ]),
      ),
    );
  }

  Widget _discoveryPanel() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
      padding: const EdgeInsets.only(top: 16, bottom: 18),
      children: [
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: VeyroAtmosphere(
            rings: true,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const VeyroMark(size: 48),
                    const SizedBox(height: 8),
                    Text('Your world,\none feed.',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: VeyroTheme.frost,
                            height: 1.16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 9),
                    Text('Moments worth sharing.\nConversations worth joining.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: VeyroTheme.lavender, height: 1.5)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                        onPressed: () => widget.onCompose(FeedComposeMode.post),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create a post')),
                  ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Topics in this feed',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (topics.isEmpty)
                      Text('Try adding a #topic to your next post.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant))
                    else
                      Wrap(spacing: 5, runSpacing: 3, children: [
                        for (final entry in topics.take(5))
                          ActionChip(
                              label: Text(entry.key),
                              onPressed: () => _browse(topic: entry.key)),
                      ]),
                    const SizedBox(height: 10),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_search_outlined,
                          color: colors.primary),
                      title: const Text('Discover people'),
                      trailing:
                          const Icon(Icons.chevron_right_rounded, size: 19),
                      onTap: () => _browse(people: true),
                    ),
                  ]),
            )),
      ],
    );
  }
}
