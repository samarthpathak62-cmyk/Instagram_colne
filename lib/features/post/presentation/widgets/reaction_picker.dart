import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/post/domain/entities/post_reaction.dart';

Future<PostReaction?> showPostReactionPicker(
        BuildContext context, PostReaction? selected) =>
    showModalBottomSheet<PostReaction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('React to this post',
                      style: context.veyroText.titleLarge),
                  const SizedBox(height: 4),
                  Text('Choose a reaction. Tap it again to remove it.',
                      style: context.veyroText.bodySmall),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final reaction in PostReaction.values)
                      ChoiceChip(
                        showCheckmark: false,
                        selected: reaction == selected,
                        avatar: ExcludeSemantics(
                            child: Text(reaction.emoji,
                                style: const TextStyle(fontSize: 18))),
                        label: Text(reaction.label),
                        onSelected: (_) => Navigator.pop(context, reaction),
                      ),
                  ]),
                ]),
          )),
    );
