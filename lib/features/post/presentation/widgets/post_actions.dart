import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/comments_sheet.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(children: [
        IconButton(
          tooltip: liked ? 'Unlike post' : 'Like post',
          icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 22,
              color: liked ? colors.primary : null),
          onPressed: state.liking
              ? null
              : () => showPostActionError(context, actions.toggleLike(post)),
        ),
        Text('${state.likes(post)}', style: style),
        IconButton(
          tooltip: 'Comments',
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
          onPressed: () => showPostComments(context, post.id),
        ),
        Text('${state.comments(post)}', style: style),
        IconButton(
          tooltip: 'Share post',
          icon: const Icon(Icons.ios_share_rounded, size: 21),
          onPressed: () => showSharePost(context, post.id),
        ),
        const Spacer(),
        IconButton(
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

Future<void> showPostActionError(
    BuildContext context, Future<String?> operation) async {
  final error = await operation;
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}
