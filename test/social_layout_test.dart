import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/social_navigation_header.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:instagram_clone/features/story/presentation/widgets/story_strip.dart';

void main() {
  for (final width in [320.0, 390.0, 1040.0, 1360.0]) {
    testWidgets(
        'responsive navigation works at ${width.toInt()}px and large text',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 680);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final desktop = width >= 1040;
      var selected = SocialSection.home;
      var messages = 0;
      var creates = 0;
      await tester.pumpWidget(MaterialApp(
        theme:
            width == 1360 || width == 320 ? VeyroTheme.dark : VeyroTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: StatefulBuilder(builder: (context, setState) {
          void choose(SocialSection section) =>
              setState(() => selected = section);
          return Scaffold(
            body: desktop
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: 210,
                      child: SocialDesktopRail(
                          selected: selected,
                          onSelect: choose,
                          onCompose: () => creates++,
                          onMessages: () => messages++,
                          onNotifications: () {},
                          unreadNotifications: 3,
                          unreadChats: 1,
                          onSaved: () {},
                          name: 'A long display name for accessibility',
                          username: 'test_user'),
                    ))
                : Column(children: [
                    SocialNavigationHeader(
                        onGroups: () => choose(SocialSection.groups),
                        onMessages: () => messages++,
                        onNotifications: () {},
                        unreadNotifications: 3,
                        unreadChats: 1),
                  ]),
            bottomNavigationBar: desktop
                ? null
                : SocialBottomBar(
                    selected: selected,
                    onSelect: choose,
                    onCompose: () => creates++,
                    name: 'Test User'),
          );
        }),
      ));
      expect(find.byType(Badge), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await tester
          .tap(desktop ? find.text('Groups') : find.byTooltip('Groups'));
      await tester.pumpAndSettle();
      expect(selected, SocialSection.groups);
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(selected, SocialSection.explore);
      await tester
          .tap(desktop ? find.text('Messages') : find.byTooltip('Messages'));
      await tester.tap(find.text('Create'));
      expect(messages, 1);
      expect(creates, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'story strip distinguishes unseen and viewed and supports discovery',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var added = 0;
      var discovered = 0;
      String? selected;
      final time = DateTime.utc(2026, 11, 18);
      final story = Story(
          id: 'friend',
          userId: 'friend',
          username: 'veyro_friend',
          lastUpdatedAt: time,
          items: [
            StoryItem(
                id: 'item',
                mediaUrl: 'video_not_loaded_for_avatar',
                mediaType: StoryMediaType.video,
                createdAt: time)
          ]);
      final seen = <String>{};
      Future<void> setup() => tester.pumpWidget(MaterialApp(
            theme: VeyroTheme.dark,
            home: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 297,
                        child: StoryStrip(
                          stories: [story],
                          ownName: 'Veyro User',
                          seenItems: seen,
                          onAddStoryTap: () => added++,
                          onStoryCircleTap: (author) => selected = author,
                          onDiscover: () => discovered++,
                        )))),
          ));
      await setup();
      await tester.tap(find.text('Add story'));
      await tester.tap(find.text('Find people'));
      expect(
          find.bySemanticsLabel('New story by veyro_friend'), findsOneWidget);
      await tester.tap(find.text('veyro_friend'));
      expect(selected, 'friend');
      seen.add('item');
      await setup();
      expect(find.bySemanticsLabel('Viewed story by veyro_friend'),
          findsOneWidget);
      expect(added, 1);
      expect(discovered, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
