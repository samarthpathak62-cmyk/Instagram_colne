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
  final bool showReactionSummary;

  const PostActions(
      {super.key, required this.post, this.showReactionSummary = true});

  @override
  Widget build(BuildContext context) {
    final actions = context.read<PostInteractionsCubit>();
    final state =
        context.select((PostInteractionsCubit cubit) => cubit.forPost(post.id));
    final reaction = state.selectedReaction(post);
    final tally =
        showReactionSummary ? state.tally(post) : const <PostReaction, int>{};
    final comments = state.comments(post);
    final colors = context.veyroColors;
    String captionWithCount(String caption, int count) =>
        showReactionSummary || count == 0
            ? caption
            : '$caption · ${_countLabel(count)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showReactionSummary && (tally.isNotEmpty || comments > 0))
          _EngagementSummary(
              reactions: tally,
              total: state.likes(post),
              comments: comments,
              onComments: () => showPostComments(context, post.id)),
        const Divider(),
        Row(children: [
          Expanded(
              flex: 4,
              child: Row(children: [
                Expanded(
                    child: _PostButton(
                  label: switch (reaction) {
                    null => 'Like post',
                    PostReaction.like => 'Unlike post',
                    _ => 'Remove ${reaction.label} reaction',
                  },
                  caption: captionWithCount(
                    reaction == PostReaction.like
                        ? 'Liked'
                        : reaction?.label ?? 'Like',
                    state.likes(post),
                  ),
                  selected: reaction != null,
                  icon: reaction == null || reaction == PostReaction.like
                      ? Icon(
                          reaction == null
                              ? Icons.thumb_up_outlined
                              : Icons.thumb_up_rounded,
                          size: 19)
                      : Text(reaction.emoji,
                          style: const TextStyle(fontSize: 17)),
                  onPressed: state.liking
                      ? null
                      : () => showPostActionError(
                          context, actions.toggleLike(post)),
                )),
                SizedBox(
                    width: 44,
                    child: IconButton(
                      tooltip: 'Choose reaction',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20),
                      color: reaction == null
                          ? colors.onSurfaceVariant
                          : colors.primary,
                      onPressed: state.liking
                          ? null
                          : () async {
                              final choice = await showPostReactionPicker(
                                  context, reaction);
                              if (choice != null && context.mounted) {
                                final current = actions
                                    .forPost(post.id)
                                    .selectedReaction(post);
                                await showPostActionError(
                                    context,
                                    actions.setReaction(post,
                                        current == choice ? null : choice));
                              }
                            },
                    )),
              ])),
          Expanded(
              flex: 3,
              child: _PostButton(
                label: 'Comments',
                caption: captionWithCount('Comment', comments),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                onPressed: () => showPostComments(context, post.id),
              )),
          Expanded(
              flex: 3,
              child: _PostButton(
                label: 'Share post',
                caption: 'Share',
                icon: const Icon(Icons.reply_rounded,
                    size: 22, textDirection: TextDirection.rtl),
                onPressed: () => showSharePost(context, post.id),
              )),
        ]),
        const SizedBox(height: 2),
      ]),
    );
  }
}

class _PostButton extends StatelessWidget {
  final String label;
  final String caption;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool? selected;

  const _PostButton(
      {required this.label,
      required this.caption,
      required this.icon,
      required this.onPressed,
      this.selected});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null,
        selected: selected,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                foregroundColor: selected == true
                    ? context.veyroColors.primary
                    : context.veyroColors.onSurfaceVariant,
              ),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    icon,
                    const SizedBox(width: 5),
                    Text(caption, style: const TextStyle(fontSize: 13)),
                  ])),
            )),
      );
}

class _EngagementSummary extends StatelessWidget {
  final Map<PostReaction, int> reactions;
  final int total;
  final int comments;
  final VoidCallback onComments;

  const _EngagementSummary(
      {required this.reactions,
      required this.total,
      required this.comments,
      required this.onComments});

  @override
  Widget build(BuildContext context) {
    final sorted = reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final style = context.veyroText.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        Expanded(
            child: Semantics(
          label: sorted
              .map((entry) => '${entry.key.label}: ${entry.value}')
              .join(', '),
          child: ExcludeSemantics(
              child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final entry in sorted.take(3))
                    Text(entry.key.emoji, style: const TextStyle(fontSize: 15)),
                  if (total > 0) Text(_countLabel(total), style: style),
                ]),
          )),
        )),
        if (comments > 0)
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: context.veyroColors.onSurfaceVariant,
                textStyle: style),
            onPressed: onComments,
            child: Text(
                '${_countLabel(comments)} ${comments == 1 ? 'comment' : 'comments'}'),
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
