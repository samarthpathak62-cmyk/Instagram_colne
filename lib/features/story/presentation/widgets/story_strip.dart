import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';

class StoryStrip extends StatelessWidget {
  final List<Story> stories;
  final String? ownAvatar;
  final String? ownName;
  final Set<String> seenItems;
  final VoidCallback onAddStoryTap;
  final ValueChanged<String> onStoryCircleTap;

  const StoryStrip(
      {super.key,
      required this.stories,
      this.ownAvatar,
      this.ownName,
      this.seenItems = const {},
      required this.onAddStoryTap,
      required this.onStoryCircleTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final behavior = ScrollConfiguration.of(context);
    return SizedBox(
      height: 104 + MediaQuery.textScalerOf(context).scale(16),
      child: ScrollConfiguration(
          behavior: behavior.copyWith(dragDevices: {
            ...behavior.dragDevices,
            PointerDeviceKind.mouse,
          }),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 1, end: 1),
            itemCount: stories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final story = index == 0 ? null : stories[index - 1];
              final author =
                  story?.username ?? story?.author?.username ?? 'Story';
              final item = story?.items
                  .where((item) => !seenItems.contains(item.id))
                  .firstOrNull;
              final media = item ?? story?.items.lastOrNull;
              final photo = media?.mediaType == StoryMediaType.image
                  ? media?.mediaUrl
                  : null;
              final label = story == null ? 'Add story' : author;
              final onTap = story == null
                  ? onAddStoryTap
                  : () => onStoryCircleTap(story.userId);
              return SizedBox(
                width: 84,
                child: Semantics(
                  button: true,
                  label: story == null
                      ? label
                      : '${item == null ? 'Viewed story' : 'New story'} by $author',
                  onTap: onTap,
                  excludeSemantics: true,
                  child: Material(
                    color: const Color(0xFF241437),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                        side: BorderSide(
                            color: item != null
                                ? const Color(0xFF995CF6)
                                : const Color(0xFF694E87))),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                        onTap: onTap,
                        child: Stack(fit: StackFit.expand, children: [
                          const VeyroAtmosphere(
                              rings: true, child: SizedBox.expand()),
                          if (photo != null && photo.isNotEmpty)
                            Image.network(photo,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink()),
                          const DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x34090012),
                              Color(0x07090012),
                              Color(0xEF090012)
                            ],
                            stops: [0, .37, 1],
                          ))),
                          PositionedDirectional(
                              top: 8,
                              start: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: item != null
                                        ? const SweepGradient(colors: [
                                            Color(0xFFC555FC),
                                            Color(0xFFF69883),
                                            Color(0xFFC555FC)
                                          ])
                                        : null,
                                    color:
                                        item == null ? Colors.white38 : null),
                                child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: UserAvatar(
                                      name: story == null ? ownName : author,
                                      imageUrl: story == null
                                          ? ownAvatar
                                          : story.profileImageUrl,
                                      radius: 15,
                                    )),
                              )),
                          if (story == null ||
                              media?.mediaType == StoryMediaType.video)
                            Center(
                                child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: story == null
                                            ? const Color(0xFF7036E5)
                                            : const Color(0x8420132E)),
                                    child: Icon(
                                        story == null
                                            ? Icons.add_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 19))),
                          PositionedDirectional(
                              start: 8,
                              end: 8,
                              bottom: 9,
                              child: Text(label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800))),
                        ])),
                  ),
                ),
              );
            },
          )),
    );
  }
}
