import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
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
    return SizedBox(
        height: 108 + scale.scale(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final tileWidth = constraints.maxWidth >= 540 ? 104.0 : 89.0;
          final create =
              SizedBox(width: tileWidth, child: _createCard(context));
          if (stories.isEmpty) {
            return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  create,
                  if (onDiscover != null)
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: onDiscover,
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Center(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                          width: (constraints.maxWidth -
                                                  tileWidth -
                                                  35)
                                              .clamp(140.0, 260.0)
                                              .toDouble(),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Follow people to see their stories',
                                                    style: context
                                                        .veyroText.titleSmall),
                                                const SizedBox(height: 5),
                                                Text('Find people →',
                                                    style: context
                                                        .veyroText.labelMedium
                                                        ?.copyWith(
                                                            color: context
                                                                .veyroColors
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800)),
                                              ]))),
                                )),
                          )),
                    )),
                ]);
          }
          return ScrollConfiguration(
              behavior: behavior.copyWith(dragDevices: {
                ...behavior.dragDevices,
                PointerDeviceKind.mouse,
              }),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => index == 0
                    ? create
                    : SizedBox(
                        width: tileWidth,
                        child: _storyCard(context, stories[index - 1]),
                      ),
              ));
        }));
  }

  Widget _createCard(BuildContext context) {
    final colors = context.veyroColors;
    return _tile(
      context,
      label: 'Add story',
      onTap: onAddStoryTap,
      background: colors.surfaceContainerLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: colors.primaryContainer),
          Align(
              alignment: const Alignment(0, -.25),
              child:
                  UserAvatar(imageUrl: ownAvatar, name: ownName, radius: 22)),
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: colors.surfaceContainerLow, width: 2),
                    color: VeyroTheme.blue),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 17),
              )),
        ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(3, 6, 3, 7),
            child: Text('Add story',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.veyroText.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _storyCard(BuildContext context, Story story) {
    final author = story.username ?? story.author?.username ?? 'Story';
    final unread =
        story.items.where((item) => !seenItems.contains(item.id)).firstOrNull;
    final media = unread ?? story.items.lastOrNull;
    final thumbnail =
        media?.mediaType == StoryMediaType.image ? media?.mediaUrl : null;
    final colors = context.veyroColors;
    return _tile(
      context,
      label: '${unread == null ? 'Viewed story' : 'New story'} by $author',
      onTap: () => onStoryCircleTap(story.userId),
      background: const Color(0xFF2A3D57),
      child: Stack(fit: StackFit.expand, children: [
        if (thumbnail != null && thumbnail.isNotEmpty)
          Image.network(thumbnail,
              fit: BoxFit.cover,
              cacheWidth: 320,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x20101A27), Colors.transparent, Color(0xEB101A27)],
          stops: [0, .43, 1],
        ))),
        PositionedDirectional(
            top: 7,
            start: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unread != null ? colors.primary : Colors.white54),
              child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: UserAvatar(
                      imageUrl: story.profileImageUrl,
                      name: author,
                      radius: 14)),
            )),
        if (media?.mediaType == StoryMediaType.video)
          const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 27)),
        PositionedDirectional(
            start: 7,
            end: 7,
            bottom: 8,
            child: Text(author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.veyroText.labelSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _tile(BuildContext context,
          {required String label,
          required VoidCallback onTap,
          required Color background,
          required Widget child}) =>
      Semantics(
        button: true,
        onTap: onTap,
        label: label,
        excludeSemantics: true,
        child: Material(
            color: background,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.veyroColors.outlineVariant)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, child: child)),
      );
}
