import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
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
                constraints: const BoxConstraints(maxWidth: 590),
                child: _body())),
      );

  Widget _body() {
    if (_reels.isEmpty) {
      if (_busy) return const Center(child: CircularProgressIndicator());
      if (_error != null)
        return CustomErrorWidget(
            message: _error!, onRetry: () => _load(reset: true));
      return Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                      radius: 32,
                      child: Icon(Icons.play_arrow_rounded,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 36)),
                  const SizedBox(height: 16),
                  Text('No reels yet',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Share a video to start the Reels feed.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                      onPressed: widget.onCreate,
                      icon: const Icon(Icons.video_call_outlined),
                      label: const Text('Create a reel')),
                ],
              )));
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PostHeader(post: post),
            Expanded(
                child: ColoredBox(
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
                              color: Colors.white, size: 42)),
            )),
            if (description.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
                  child: Text(description,
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
            PostActions(post: post),
          ])),
    );
  }
}
