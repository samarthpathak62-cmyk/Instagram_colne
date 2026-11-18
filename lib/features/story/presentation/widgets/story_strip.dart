import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';

class StoryStrip extends StatelessWidget {
  final List<Story> stories;
  final String? ownAvatar;
  final String? ownName;
  final Set<String> seenItems;
  final VoidCallback? onDiscover;
  final VoidCallback onAddStoryTap;
  final ValueChanged<String> onStoryCircleTap;

  const StoryStrip(
      {super.key,
      required this.stories,
      this.ownAvatar,
      this.ownName,
      this.seenItems = const {},
      this.onDiscover,
      required this.onAddStoryTap,
      required this.onStoryCircleTap});

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    final scale = MediaQuery.textScalerOf(context);
    // A real discovery action rather than filling unused slots with fake stories.
    final showDiscover = onDiscover != null && stories.length < 2;
    return SizedBox(
      height: 79 + scale.scale(14) * 1.4,
      child: ScrollConfiguration(
        behavior: behavior.copyWith(
            dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse}),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          scrollDirection: Axis.horizontal,
          itemCount: 1 + stories.length + (showDiscover ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            if (index == 0) return _create(context);
            if (index > stories.length) return _discover(context);
            return _story(context, stories[index - 1]);
          },
        ),
      ),
    );
  }

  Widget _create(BuildContext context) => _bubble(
        context,
        caption: 'Add story',
        label: 'Add story',
        onTap: onAddStoryTap,
        portrait: Stack(clipBehavior: Clip.none, children: [
          VeyroOrbitRing(
              glowing: false,
              child:
                  UserAvatar(imageUrl: ownAvatar, name: ownName, radius: 28)),
          PositionedDirectional(
              end: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VeyroTheme.violet,
                    border: Border.all(
                        color: context.veyroColors.surface, width: 2)),
                child: const Padding(
                    padding: EdgeInsets.all(2),
                    child:
                        Icon(Icons.add_rounded, color: Colors.white, size: 16)),
              )),
        ]),
      );

  Widget _discover(BuildContext context) {
    final colors = context.veyroColors;
    return _bubble(
      context,
      caption: 'Find people',
      label: 'Find people',
      onTap: onDiscover!,
      portrait: VeyroOrbitRing(
          glowing: false,
          child: CircleAvatar(
              radius: 28,
              backgroundColor: colors.surfaceContainerHigh,
              foregroundColor: colors.primary,
              child: const Icon(Icons.person_search_outlined, size: 26))),
    );
  }

  Widget _story(BuildContext context, Story story) {
    final username = story.username ?? story.author?.username ?? 'Story';
    final unread =
        story.items.where((item) => !seenItems.contains(item.id)).firstOrNull;
    final last = unread ?? story.items.lastOrNull;
    final thumbnail =
        last?.mediaType == StoryMediaType.image ? last?.mediaUrl : null;
    final avatar = story.profileImageUrl;
    return _bubble(
      context,
      caption: username,
      label: '${unread == null ? 'Viewed story' : 'New story'} by $username',
      onTap: () => onStoryCircleTap(story.userId),
      portrait: VeyroOrbitRing(
          glowing: unread != null,
          child: UserAvatar(
              imageUrl: avatar?.isNotEmpty == true ? avatar : thumbnail,
              name: username,
              radius: 28)),
    );
  }

  Widget _bubble(BuildContext context,
          {required String caption,
          required String label,
          required VoidCallback onTap,
          required Widget portrait}) =>
      SizedBox(
        width: 79,
        child: Semantics(
          label: label,
          button: true,
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(15),
                child: Column(children: [
                  const SizedBox(height: 3),
                  portrait,
                  const SizedBox(height: 5),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.veyroText.labelSmall?.copyWith(
                              color: context.veyroColors.onSurface,
                              fontWeight: FontWeight.w700))),
                ]),
              )),
        ),
      );
}
