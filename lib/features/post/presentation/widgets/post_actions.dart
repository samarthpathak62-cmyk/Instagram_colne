import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/domain/entities/post_reaction.dart';
import 'package:instagram_clone/features/post/presentation/widgets/reaction_picker.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/comments_sheet.dart';
import 'package:instagram_clone/features/post/presentation/screens/repost_sheet.dart';
import 'package:instagram_clone/features/post/presentation/screens/share_post_sheet.dart';

class PostActions extends StatelessWidget {
  final Post post;

  final bool showReactionSummary;

  const PostActions(
      {super.key, required this.post, this.showReactionSummary = true});

  @override
  Widget build(BuildContext context) {
    final actions = context.read<PostInteractionsCubit>();
    final state =
        context.select((PostInteractionsCubit cubit) => cubit.forPost(post.id));
    final reaction = state.selectedReaction(post);
    final reactions =
        showReactionSummary ? state.tally(post) : const <PostReaction, int>{};
    final saved = state.isSaved(post);
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium;
    final compact = IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 7),
    );
    Widget action({
      required String tooltip,
      required Widget icon,
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (reactions.isNotEmpty)
          Semantics(
            label: reactions.entries
                .map((entry) => '${entry.key.label}: ${entry.value}')
                .join(', '),
            child: ExcludeSemantics(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
              child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final item
                        in PostReaction.values.where(reactions.containsKey))
                      Text(item.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 2),
                    Text(
                        '${_countLabel(state.likes(post))} ${state.likes(post) == 1 ? 'reaction' : 'reactions'}',
                        style: style?.copyWith(color: colors.onSurfaceVariant)),
                  ]),
            )),
          ),
        Row(children: [
          action(
            tooltip: switch (reaction) {
              null => 'Like post',
              PostReaction.like => 'Unlike post',
              _ => 'Remove ${reaction.label} reaction',
            },
            icon: reaction == null || reaction == PostReaction.like
                ? Icon(
                    reaction == null
                        ? Icons.favorite_border_rounded
                        : Icons.favorite_rounded,
                    size: 22,
                    color: reaction == null ? null : colors.primary)
                : ExcludeSemantics(
                    child: Text(reaction.emoji,
                        style: const TextStyle(fontSize: 18))),
            count: showReactionSummary ? null : state.likes(post),
            countName: 'reactions',
            onTap: state.liking
                ? null
                : () => showPostActionError(context, actions.toggleLike(post)),
          ),
          action(
            tooltip: 'Choose reaction',
            icon: Icon(Icons.add_reaction_outlined,
                size: 21, color: reaction == null ? null : colors.primary),
            onTap: state.liking
                ? null
                : () async {
                    final choice =
                        await showPostReactionPicker(context, reaction);
                    if (choice != null && context.mounted) {
                      final current =
                          actions.forPost(post.id).selectedReaction(post);
                      await showPostActionError(
                          context,
                          actions.setReaction(
                              post, current == choice ? null : choice));
                    }
                  },
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
