import 'package:instagram_clone/core/theme/veyro_theme.dart';
// lib/features/story/presentation/widgets/story_circles_widget.dart

import 'package:flutter/material.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';

class StoryCirclesWidget extends StatelessWidget {
  final List<Story> stories;
  final VoidCallback? onAddStoryTap;
  final Function(String userId)? onStoryCircleTap;

  const StoryCirclesWidget({
    Key? key,
    required this.stories,
    this.onAddStoryTap,
    this.onStoryCircleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84 + MediaQuery.textScalerOf(context).scale(14),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemExtent: 80,
        itemCount: stories.length +
            (onAddStoryTap != null
                ? 1
                : 0), // Add 1 for 'Your Story' if applicable
        itemBuilder: (context, index) {
          if (onAddStoryTap != null && index == 0) {
            // This is the 'Your Story' item
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GestureDetector(
                onTap: onAddStoryTap,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        UserAvatar(
                          imageUrl:
                              null, // Current user's avatar will be here, or a placeholder
                          radius: 30,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: VeyroTheme.violet,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  width: 2),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your Story',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Regular story circle
            final storyIndex = onAddStoryTap != null ? index - 1 : index;
            final story = stories[storyIndex];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GestureDetector(
                onTap: () => onStoryCircleTap?.call(story.userId),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: story.isViewed
                              ? context.veyroColors.outline
                              : context.veyroColors.primary,
                          width: 3,
                        ),
                      ),
                      child: UserAvatar(
                        imageUrl: story.userProfileImageUrl,
                        radius: 30,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.username ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
