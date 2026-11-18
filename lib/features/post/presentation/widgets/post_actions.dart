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
    Widget withCount(Icon icon, int count) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(_countLabel(count), style: style)
          ],
        ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(children: [
        IconButton(
          tooltip: liked ? 'Unlike post' : 'Like post',
          style: compact,
          icon: withCount(
              Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 22,
                  color: liked ? colors.primary : null),
              state.likes(post)),
          onPressed: state.liking
              ? null
              : () => showPostActionError(context, actions.toggleLike(post)),
        ),
        IconButton(
          tooltip: 'Comments',
          style: compact,
          icon: withCount(
              const Icon(Icons.chat_bubble_outline_rounded, size: 21),
              state.comments(post)),
          onPressed: () => showPostComments(context, post.id),
        ),
        IconButton(
          tooltip: 'Repost options',
          style: compact,
          icon: const Icon(Icons.repeat_rounded, size: 22),
          onPressed: post.shareTargetId == null
              ? null
              : () => showRepostOptions(context, post),
        ),
        IconButton(
          tooltip: 'Share post',
          style: compact,
          icon: const Icon(Icons.ios_share_rounded, size: 21),
          onPressed: () => showSharePost(context, post.id),
        ),
        const Spacer(),
        IconButton(
          style: compact,
          tooltip: saved ? 'Remove from saved' : 'Save post',
          icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 23,
              color: saved ? colors.primary : null),
          onPressed: state.saving
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
