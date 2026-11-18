import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/comments_sheet.dart';
import 'package:instagram_clone/features/post/presentation/screens/repost_sheet.dart';
import 'package:instagram_clone/features/post/presentation/screens/share_post_sheet.dart';

class PostActions extends StatelessWidget {
  final Post post;

  const PostActions({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final actions = context.read<PostInteractionsCubit>();
    final state =
        context.select((PostInteractionsCubit cubit) => cubit.forPost(post.id));
    final liked = state.isLiked(post);
    final saved = state.isSaved(post);
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium;
    final compact = IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 7),
    );
    Widget action({
      required String tooltip,
      required Icon icon,
      required VoidCallback? onTap,
      int? count,
      String? countName,
    }) =>
        Expanded(
          child: Semantics(
            value: count == null ? null : '$count $countName',
            child: IconButton(
              tooltip: tooltip,
              style: compact,
              onPressed: onTap,
              icon: count == null || count <= 0
                  ? icon
                  : ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          icon,
                          const SizedBox(width: 4),
                          Text(_countLabel(count), style: style),
                        ]),
                      ),
                    ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(children: [
        action(
          tooltip: liked ? 'Unlike post' : 'Like post',
          icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 22,
              color: liked ? colors.primary : null),
          count: state.likes(post),
          countName: 'likes',
          onTap: state.liking
              ? null
              : () => showPostActionError(context, actions.toggleLike(post)),
        ),
        action(
          tooltip: 'Comments',
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
          count: state.comments(post),
          countName: 'comments',
          onTap: () => showPostComments(context, post.id),
        ),
        action(
          tooltip: 'Repost options',
          icon: const Icon(Icons.repeat_rounded, size: 22),
          onTap: post.shareTargetId == null
              ? null
              : () => showRepostOptions(context, post),
        ),
        action(
          tooltip: 'Share post',
          icon: const Icon(Icons.ios_share_rounded, size: 21),
          onTap: () => showSharePost(context, post.id),
        ),
        action(
          tooltip: saved ? 'Remove from saved' : 'Save post',
          icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 23,
              color: saved ? colors.primary : null),
          onTap: state.saving
              ? null
              : () => showPostActionError(context, actions.toggleSave(post)),
        ),
      ]),
    );
  }
}

String _countLabel(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
  if (count < 1000000000) return '${(count / 1000000).toStringAsFixed(1)}m';
  return '${(count / 1000000000).toStringAsFixed(1)}b';
}

Future<void> showPostActionError(
    BuildContext context, Future<String?> operation) async {
  final error = await operation;
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}
