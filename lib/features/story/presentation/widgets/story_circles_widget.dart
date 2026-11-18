import 'package:flutter/material.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';

class StoryCirclesWidget extends StatelessWidget {
  final List<Story> stories;
  final String? ownAvatar;
  final String? ownName;
  final Set<String> seenItems;
  final VoidCallback? onAddStoryTap;
  final ValueChanged<String>? onStoryCircleTap;

  const StoryCirclesWidget({
    super.key,
    required this.stories,
    this.ownAvatar,
    this.ownName,
    this.seenItems = const {},
    this.onAddStoryTap,
    this.onStoryCircleTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72 + MediaQuery.textScalerOf(context).scale(14),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 2, end: 6),
        itemExtent: 71,
        itemCount: stories.length + (onAddStoryTap != null ? 1 : 0),
        itemBuilder: (context, index) {
          final add = onAddStoryTap != null && index == 0;
          final story =
              add ? null : stories[index - (onAddStoryTap != null ? 1 : 0)];
          final label = story?.username ?? (add ? 'Add story' : 'Story');
          final seen =
              story?.items.every((item) => seenItems.contains(item.id)) ?? true;
          final surface = colors.surface;
          return Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: add
                  ? onAddStoryTap
                  : () => onStoryCircleTap?.call(story!.userId),
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: add
                          ? colors.outlineVariant
                          : seen
                              ? colors.outline
                              : null,
                      gradient: seen
                          ? null
                          : const SweepGradient(colors: [
                              Color(0xFF7950F4),
                              Color(0xFFE95C9A),
                              Color(0xFFF1AF7B),
                              Color(0xFF7950F4),
                            ]),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, color: surface),
                      child: UserAvatar(
                        imageUrl: add ? ownAvatar : story?.userProfileImageUrl,
                        name: add ? ownName : story?.username,
                        radius: 24,
                      ),
                    ),
                  ),
                  if (add)
                    PositionedDirectional(
                      end: -1,
                      bottom: -1,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                          border: Border.all(color: surface, width: 2),
                        ),
                        child: Icon(Icons.add_rounded,
                            size: 17, color: colors.onPrimary),
                      ),
                    ),
                ]),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
