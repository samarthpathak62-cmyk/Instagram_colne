import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/groups/presentation/group_post_origin.dart';
import 'package:instagram_clone/features/post/domain/repositories/post_repository.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_actions.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_header.dart';
import 'package:instagram_clone/features/post/presentation/widgets/video_player_widget.dart';

class VideoExploreTab extends StatefulWidget {
  final VoidCallback onCreate;

  const VideoExploreTab({super.key, required this.onCreate});

  @override
  State<VideoExploreTab> createState() => _VideoExploreTabState();
}

class _VideoExploreTabState extends State<VideoExploreTab> {
  static const _limit = 10;
  final _pages = PageController();
  final _reels = <Post>[];
  int _offset = 0;
  int _index = 0;
  bool _busy = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy || (!reset && !_hasMore)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final batch = await sl<PostRepository>()
        .getVideoExplorePosts(limit: _limit, offset: reset ? 0 : _offset);
    if (!mounted) return;
    setState(() {
      _busy = false;
      batch.fold((failure) => _error = failure.message, (results) {
        if (reset) {
          if (_pages.hasClients) _pages.jumpToPage(0);
          _offset = 0;
          _index = 0;
          _reels.clear();
        }
        final seen = _reels.map((post) => post.id).toSet();
        _reels.addAll(results.where((post) => seen.add(post.id)));
        _offset += results.length;
        _hasMore = results.length == _limit;
      });
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) => _pages.animateToPage(index,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reels'), actions: [
          IconButton(
              tooltip: 'Refresh reels',
              onPressed: _busy ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Create a reel',
              onPressed: widget.onCreate,
              icon: const Icon(Icons.video_call_outlined)),
          const SizedBox(width: 6),
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 510),
                child: _body())),
      );

  Widget _body() {
    if (_reels.isEmpty) {
      if (_busy) return const Center(child: CircularProgressIndicator());
      if (_error != null)
        return CustomErrorWidget(
            message: _error!, onRetry: () => _load(reset: true));
      return VeyroEmptyState(
          icon: Icons.movie_outlined,
          title: 'Make a little motion',
          description: 'Share a video to start the Reels feed.',
          action: FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.video_call_outlined),
              label: const Text('Create a reel')));
    }
    final tail = _index == _reels.length - 1;
    return Column(children: [
      Expanded(
          child: PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: (index) {
          setState(() => _index = index);
          if (index >= _reels.length - 2 && _error == null) _load();
        },
        itemBuilder: (_, index) => _Reel(
            key: ValueKey(_reels[index].id),
            post: _reels[index],
            active: index == _index),
      )),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            tooltip: 'Previous reel',
            onPressed: _index == 0 ? null : () => _goTo(_index - 1),
            icon: const Icon(Icons.keyboard_arrow_up_rounded)),
        Text('${_index + 1} / ${_reels.length}',
            style: Theme.of(context).textTheme.labelMedium),
        IconButton(
            tooltip: 'Next reel',
            onPressed: tail ? null : () => _goTo(_index + 1),
            icon: const Icon(Icons.keyboard_arrow_down_rounded)),
        if (_busy)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_error != null || (tail && _hasMore))
          TextButton(
              onPressed: () => _load(reset: _error != null),
              child: Text(_error == null ? 'Load more' : 'Retry')),
      ]),
    ]);
  }
}

class _Reel extends StatelessWidget {
  final Post post;
  final bool active;
  const _Reel({super.key, required this.post, required this.active});

  @override
  Widget build(BuildContext context) {
    final state = context
        .select((PostInteractionsCubit actions) => actions.forPost(post.id));
    if (state.deleted)
      return const Center(
          child: Text('This reel was deleted. Swipe for another.'));
    final url = post.mediaUrls.firstOrNull;
    final description = state.text(post);
    Widget video() => ColoredBox(
          color: Colors.black,
          child: url == null || url.isEmpty
              ? const Center(
                  child: Text('Video unavailable',
                      style: TextStyle(color: Colors.white)))
              : active
                  ? VideoPlayerWidget(
                      key: ValueKey(url),
                      videoUrl: url,
                      autoPlay: true,
                      muted: true,
                      loop: true)
                  : const Center(
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white70, size: 42)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Theme(
          data: VeyroTheme.dark,
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxHeight < 445 ||
                MediaQuery.textScalerOf(context).scale(14) > 23;
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          PostHeader(post: post),
                          Expanded(child: video()),
                          PostActions(post: post),
                        ])
                  : Stack(fit: StackFit.expand, children: [
                      video(),
                      const IgnorePointer(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xBE100D17),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xF0100D17)
                        ],
                        stops: [0, .24, .55, 1],
                      )))),
                      PositionedDirectional(
                          top: 0,
                          start: 0,
                          end: 0,
                          child: Material(
                            color: const Color(0x78100D17),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PostHeader(post: post),
                                  if (post.groupId != null)
                                    GroupPostOrigin(post: post),
                                ]),
                          )),
                      PositionedDirectional(
                          bottom: 55,
                          end: 8,
                          child: PostActions(post: post, forReel: true)),
                      if (description.isNotEmpty)
                        PositionedDirectional(
                            start: 15,
                            end: 69,
                            bottom: 60,
                            child: IgnorePointer(
                              child: Text(description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.veyroText.bodyMedium?.copyWith(
                                      color: VeyroTheme.frost,
                                      shadows: [
                                        const Shadow(
                                            color: Colors.black, blurRadius: 6)
                                      ])),
                            )),
                    ]),
            );
          })),
    );
  }
}
