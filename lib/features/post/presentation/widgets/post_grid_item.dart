import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';

class PostGridItem extends StatelessWidget {
  final Post post;
  final Widget? trailing;

  const PostGridItem({super.key, required this.post, this.trailing});

  @override
  Widget build(BuildContext context) {
    final mediaPost =
        post.shareKind == PostShareKind.repost ? post.sharedPost ?? post : post;
    final text = context.select((PostInteractionsCubit actions) =>
        actions.forPost(mediaPost.id).text(mediaPost));
    final colors = Theme.of(context).colorScheme;
    final url = mediaPost.mediaUrls.firstOrNull;
    return Material(
      color: post.type == PostType.text
          ? colors.surfaceContainerHigh
          : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (mediaPost.type == PostType.image && url != null && url.isNotEmpty)
          Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)))
        else
          Center(
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        switch (mediaPost.type) {
                          PostType.video => Icons.play_circle_outline_rounded,
                          PostType.text => Icons.subject_rounded,
                          PostType.image => Icons.image_not_supported_outlined,
                        },
                        color: colors.primary,
                        size: 23),
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Flexible(
                          child: Text(text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium)),
                    ],
                  ]))),
        Semantics(
          label:
              'Open ${post.type == PostType.text ? 'text post' : post.type == PostType.video ? 'video' : 'photo post'}',
          button: true,
          child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PostDetailScreen(postId: post.id)))),
        ),
        if (post.shareKind != null)
          PositionedDirectional(
              top: 5,
              start: 5,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(7)),
                  child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        post.shareKind == PostShareKind.repost
                            ? Icons.repeat_rounded
                            : Icons.format_quote_rounded,
                        color: colors.onPrimaryContainer,
                        size: 14,
                      )),
                ),
              )),
        if (trailing != null)
          PositionedDirectional(top: 3, end: 3, child: trailing!),
      ]),
    );
  }
}
