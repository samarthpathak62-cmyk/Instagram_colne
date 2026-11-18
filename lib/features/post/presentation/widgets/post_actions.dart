import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/domain/entities/post_reaction.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/comments_sheet.dart';
import 'package:instagram_clone/features/post/presentation/screens/share_post_sheet.dart';
import 'package:instagram_clone/features/post/presentation/widgets/reaction_picker.dart';

class PostActions extends StatelessWidget {
  final Post post;
  final Widget? caption;
  final bool forReel;

  const PostActions(
      {super.key, required this.post, this.caption, this.forReel = false});

  @override
  Widget build(BuildContext context) {
    final actions = context.read<PostInteractionsCubit>();
    final state =
        context.select((PostInteractionsCubit cubit) => cubit.forPost(post.id));
    final reaction = state.selectedReaction(post);
    final tally = state.tally(post);
    final total = state.likes(post);
    final comments = state.comments(post);
    final colors = context.veyroColors;
    final likedColor = colors.brightness == Brightness.dark
        ? const Color(0xFFFF92B8)
        : const Color(0xFFBC345F);
    final saved = state.isSaved(post);
    void openComments() => showPostComments(context, post.id);
    final buttons = [
      IconButton(
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
                size: 25)
            : ExcludeSemantics(
                child:
                    Text(reaction.emoji, style: const TextStyle(fontSize: 21))),
        color: reaction == PostReaction.like ? likedColor : colors.onSurface,
        onPressed: state.liking
            ? null
            : () => showPostActionError(context, actions.toggleLike(post)),
      ),
      IconButton(
        tooltip: 'Choose reaction',
        icon: const Icon(Icons.expand_more_rounded, size: 19),
        color: colors.onSurfaceVariant,
        onPressed: state.liking
            ? null
            : () async {
                final choice = await showPostReactionPicker(context, reaction);
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
      IconButton(
          tooltip: 'Comments',
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 23),
          onPressed: openComments),
      IconButton(
          tooltip: 'Share post',
          icon: const Icon(Icons.send_outlined, size: 23),
          onPressed: () => showSharePost(context, post.id)),
      if (!forReel) const Spacer(),
      IconButton(
          tooltip: saved ? 'Remove from saved' : 'Save post',
          color: saved ? colors.primary : colors.onSurface,
          icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 25),
          onPressed: state.saving
              ? null
              : () => showPostActionError(context, actions.toggleSave(post))),
    ];
    if (forReel) {
      return IconButtonTheme(
          data: IconButtonThemeData(
              style: IconButton.styleFrom(
            backgroundColor: const Color(0xB3140D1C),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          )),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final button in buttons)
              Padding(padding: const EdgeInsets.only(top: 4), child: button),
            if (total > 0 || comments > 0)
              Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Semantics(
                    label: '$total reactions, $comments comments',
                    child: ExcludeSemantics(
                        child: Text(
                      [
                        if (total > 0) '♥${_countLabel(total)}',
                        if (comments > 0) '◌${_countLabel(comments)}'
                      ].join('  '),
                      style: context.veyroText.labelSmall?.copyWith(
                          color: VeyroTheme.frost,
                          shadows: [const Shadow(blurRadius: 5)]),
                    )),
                  )),
          ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: buttons)),
      if (total > 0 || caption != null || comments > 0)
        Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (total > 0) _ReactionTally(tally: tally, total: total),
                if (total > 0 && caption != null) const SizedBox(height: 5),
                if (caption != null) caption!,
                if (comments > 0)
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                        alignment: AlignmentDirectional.centerStart,
                        textStyle: context.veyroText.bodySmall),
                    onPressed: openComments,
                    child: Text(
                        'View ${_countLabel(comments)} ${comments == 1 ? 'comment' : 'comments'}'),
                  ),
              ],
            )),
      const SizedBox(height: 3),
    ]);
  }
}

class _ReactionTally extends StatelessWidget {
  final Map<PostReaction, int> tally;
  final int total;
  const _ReactionTally({required this.tally, required this.total});

  @override
  Widget build(BuildContext context) {
    final sorted = tally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Semantics(
      label: sorted
          .map((entry) => '${entry.key.label}: ${entry.value}')
          .join(', '),
      child: ExcludeSemantics(
          child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
            for (final entry in sorted.take(3))
              Text(entry.key.emoji, style: const TextStyle(fontSize: 14)),
            Text(
                '${_countLabel(total)} ${total == 1 ? 'reaction' : 'reactions'}',
                style: context.veyroText.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ])),
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
