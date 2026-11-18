import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/social_navigation_header.dart';
import 'package:instagram_clone/features/story/presentation/widgets/story_strip.dart';

void main() {
  for (final width in [320.0, 390.0, 1000.0, 1360.0]) {
    testWidgets('top navigation fits and works at ${width.toInt()}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 680);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var selected = SocialSection.home;
      var messages = 0;
      var search = 0;
      await tester.pumpWidget(MaterialApp(
        theme: width == 1360 ? VeyroTheme.dark : VeyroTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => SocialNavigationHeader(
                      selected: selected,
                      onSelect: (section) => setState(() => selected = section),
                      onCompose: () {},
                      onSearch: () => search++,
                      onMessages: () => messages++,
                      onNotifications: () {},
                    ))),
      ));
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(selected, SocialSection.groups);
      await tester.tap(find.byTooltip('Messages'));
      await tester.tap(
          width >= 1000 ? find.text('Search Veyro') : find.byTooltip('Search'));
      expect(messages, 1);
      expect(search, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty stories offer creation and real people discovery',
      (tester) async {
    var added = 0;
    var discovered = 0;
    await tester.pumpWidget(MaterialApp(
        theme: VeyroTheme.light,
        home: Scaffold(
            body: Center(
          child: SizedBox(
              width: 300,
              child: StoryStrip(
                stories: const [],
                ownName: 'Veyro User',
                onAddStoryTap: () => added++,
                onStoryCircleTap: (_) {},
                onDiscover: () => discovered++,
              )),
        ))));
    await tester.tap(find.text('Add story'));
    await tester.tap(find.text('Find people →'));
    expect(added, 1);
    expect(discovered, 1);
    expect(tester.takeException(), isNull);
  });
}
