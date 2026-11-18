import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

enum SocialSection {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  explore('Explore', Icons.explore_outlined, Icons.explore_rounded),
  reels(
      'Reels', Icons.video_collection_outlined, Icons.video_collection_rounded),
  groups('Groups', Icons.groups_outlined, Icons.groups_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  const SocialSection(this.label, this.icon, this.activeIcon);
}

/// Social destinations stay in the same order on both layouts. Compact
/// screens put them beneath the toolbar instead of shrinking five tabs beside it.
class SocialNavigationHeader extends StatelessWidget {
  final SocialSection selected;
  final ValueChanged<SocialSection> onSelect;
  final VoidCallback onCompose;
  final VoidCallback onSearch;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;

  const SocialNavigationHeader(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onCompose,
      required this.onSearch,
      required this.onMessages,
      required this.onNotifications});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (colors.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: colors.surface,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Material(
        color: colors.surfaceContainerLow,
        child: LayoutBuilder(builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            SafeArea(
                bottom: false,
                child: desktop ? _desktop(context) : _compact(context)),
            const Divider(),
          ]);
        }),
      ),
    );
  }

  Widget _identity(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const VeyroMark(size: 36),
        VeyroWordmark(
            size: 26, showMark: false, color: context.veyroColors.primary),
      ]);

  Widget _desktop(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1472),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            SizedBox(
                width: 246,
                child: Row(children: [
                  _identity(context),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('Search Veyro',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: TextButton.styleFrom(
                      backgroundColor: context.veyroColors.surface,
                      foregroundColor: context.veyroColors.onSurfaceVariant,
                      minimumSize: const Size(0, 42),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  )),
                ])),
            Expanded(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _tabs(desktop: true)))),
            SizedBox(width: 246, child: _actions(context, desktop: true)),
          ]),
        ),
      ));

  Widget _compact(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(9, 4, 7, 2),
            child: Row(children: [
              Expanded(
                  child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                          fit: BoxFit.scaleDown, child: _identity(context)))),
              _actions(context, desktop: false),
            ])),
        _tabs(desktop: false),
      ]);

  Widget _actions(BuildContext context, {required bool desktop}) {
    final colors = context.veyroColors;
    Widget circle(String name, IconData icon, VoidCallback onTap,
            {bool accented = false}) =>
        Padding(
            padding: const EdgeInsetsDirectional.only(start: 3),
            child: IconButton(
              tooltip: name,
              onPressed: onTap,
              icon: Icon(icon, size: 21),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                backgroundColor: accented
                    ? colors.primaryContainer
                    : colors.surfaceContainerHigh,
                foregroundColor:
                    accented ? colors.onPrimaryContainer : colors.onSurface,
              ),
            ));
    return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (desktop)
            FilledButton.icon(
                onPressed: onCompose,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Create'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: const StadiumBorder()))
          else ...[
            circle('Create a post', Icons.add_rounded, onCompose,
                accented: true),
            circle('Search', Icons.search_rounded, onSearch),
          ],
          circle('Notifications', Icons.notifications_none_rounded,
              onNotifications),
          circle('Messages', Icons.chat_bubble_outline_rounded, onMessages),
        ]);
  }

  Widget _tabs({required bool desktop}) => Row(children: [
        for (final section in SocialSection.values)
          Expanded(
              child: _SectionTab(
            section: section,
            selected: section == selected,
            desktop: desktop,
            onTap: () => onSelect(section),
          )),
      ]);
}

class _SectionTab extends StatelessWidget {
  final SocialSection section;
  final bool selected;
  final bool desktop;
  final VoidCallback onTap;

  const _SectionTab(
      {required this.section,
      required this.selected,
      required this.desktop,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    final content = [
      Icon(selected ? section.activeIcon : section.icon,
          size: 23, color: foreground),
      SizedBox(height: desktop ? 0 : 2, width: desktop ? 6 : 0),
      Text(section.label,
          maxLines: 1,
          style: TextStyle(
              color: foreground,
              fontSize: desktop ? 13 : 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700)),
    ];
    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
          onTap: onTap,
          child: Container(
            height: desktop ? 62 : 52,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 3,
            ))),
            child: Center(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: desktop
                        ? Row(mainAxisSize: MainAxisSize.min, children: content)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: content))),
          )),
    );
  }
}
