import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_actions.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_header.dart';
import 'package:instagram_clone/features/post/presentation/widgets/video_player_widget.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool inDetail;

  const PostCard({super.key, required this.post, this.inDetail = false});

  @override
  Widget build(BuildContext context) {
    final state =
        context.select((PostInteractionsCubit cubit) => cubit.forPost(post.id));
    if (state.deleted) return const SizedBox.shrink();
    final text = state.text(post);
    final media = post.mediaUrls.where((url) => url.isNotEmpty).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PostHeader(post: post, showOpenPost: !inDetail),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 3, 15, 13),
            child: SelectableText(text,
                style: post.type == PostType.text
                    ? Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(height: 1.55)
                    : Theme.of(context).textTheme.bodyMedium),
          ),
        if (post.type != PostType.text && media.isNotEmpty)
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: AspectRatio(
              aspectRatio: post.type == PostType.video ? 16 / 10 : 1,
              child: post.type == PostType.video
                  ? VideoPlayerWidget(
                      key: ValueKey(media.first),
                      videoUrl: media.first,
                      loadOnTap: true)
                  : _PostPhotos(
                      urls: media,
                      onDoubleTap: () => showPostActionError(
                          context,
                          context
                              .read<PostInteractionsCubit>()
                              .toggleLike(post, likeOnly: true))),
            ),
          ),
        if (post.type != PostType.text && media.isEmpty)
          const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Media is no longer available.')),
        PostActions(post: post),
      ]),
    );
  }
}

class _PostPhotos extends StatefulWidget {
  final List<String> urls;
  final VoidCallback onDoubleTap;
  const _PostPhotos({required this.urls, required this.onDoubleTap});

  @override
  State<_PostPhotos> createState() => _PostPhotosState();
}

class _PostPhotosState extends State<_PostPhotos> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) => _controller.animateToPage(index,
      duration: const Duration(milliseconds: 230), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.urls.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (_, index) => GestureDetector(
            onDoubleTap: widget.onDoubleTap,
            child: Image.network(
              widget.urls[index],
              fit: BoxFit.contain,
              semanticLabel: 'Post photo ${index + 1}',
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('Could not load photo.')),
            ),
          ),
        ),
        if (widget.urls.length > 1) ...[
          if (_index > 0)
            Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  tooltip: 'Previous photo',
                  onPressed: () => _go(_index - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                )),
          if (_index < widget.urls.length - 1)
            Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  tooltip: 'Next photo',
                  onPressed: () => _go(_index + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                )),
          PositionedDirectional(
              end: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    child: Text('${_index + 1} / ${widget.urls.length}',
                        style: const TextStyle(color: Colors.white))),
              )),
        ],
      ]);
}
