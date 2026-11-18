import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/loading_indicator.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
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
              constraints: BoxConstraints(maxWidth: wide ? 986 : 640),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _timeline()),
                      if (wide) ...[
                        const SizedBox(width: 20),
                        SizedBox(width: 250, child: _discoveryPanel()),
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
      const SizedBox(height: 14),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              UserAvatar(
                  imageUrl: user?.profilePictureUrl,
                  name: user?.name ?? user?.username,
                  radius: 20),
              const SizedBox(width: 9),
              Expanded(
                  child: TextButton(
                style: TextButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurfaceVariant,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.bodyMedium,
                ),
                onPressed: () => widget.onCompose(FeedComposeMode.post),
                child: const Text('What’s on your mind?',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
            ]),
            const SizedBox(height: 10),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _composeButton(FeedComposeMode.post, Icons.notes_rounded, 'Text',
                  colors.primary),
              _composeButton(
                  FeedComposeMode.photo,
                  Icons.photo_library_outlined,
                  'Photo',
                  colors.brightness == Brightness.dark
                      ? const Color(0xFF84DEA8)
                      : const Color(0xFF16764B)),
              _composeButton(
                  FeedComposeMode.reel,
                  Icons.video_collection_outlined,
                  'Reel',
                  colors.brightness == Brightness.dark
                      ? const Color(0xFFFFA1AE)
                      : const Color(0xFFB73B54)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(3, 0, 4, 8),
        child: Row(children: [
          Expanded(child: Text('Stories', style: theme.textTheme.titleMedium)),
          Text('24 hours',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      ),
      FeedStoriesBar(onDiscover: () => _browse(people: true)),
      const SizedBox(height: 12),
      Row(children: [
        Padding(
            padding: const EdgeInsetsDirectional.only(start: 3, end: 10),
            child: Text('Feed', style: theme.textTheme.titleMedium)),
        Expanded(
            child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 3,
                children: [
              for (final timeline in FeedTimeline.values)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                      timeline == FeedTimeline.latest ? 'Latest' : 'Following'),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: timeline == state.timeline
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                  selected: timeline == state.timeline,
                  onSelected: (_) => feed.selectTimeline(timeline),
                ),
            ])),
        IconButton(
            tooltip: 'Refresh feed',
            onPressed: feed.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 20)),
      ]),
      if (state.refreshing && state.items.isNotEmpty)
        const LinearProgressIndicator(minHeight: 2),
    ]);
  }

  Widget _composeButton(
          FeedComposeMode mode, IconData icon, String label, Color tint) =>
      Expanded(
          child: TextButton(
        onPressed: () => widget.onCompose(mode),
        style: TextButton.styleFrom(
          foregroundColor: context.veyroColors.onSurfaceVariant,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ExcludeSemantics(child: Icon(icon, size: 20, color: tint)),
              const SizedBox(width: 5),
              Text(label),
            ])),
      ));

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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                    radius: 17,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: const Icon(Icons.groups_outlined, size: 21)),
                const SizedBox(width: 9),
                Expanded(
                    child: Text('Communities',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 9),
              Text('Find groups for the things you care about.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 11),
              SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: widget.onGroups,
                    style: TextButton.styleFrom(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer),
                    child: const Text('Browse groups'),
                  )),
            ]),
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
