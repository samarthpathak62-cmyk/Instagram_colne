import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';

enum SocialSection {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  explore('Explore', Icons.search_rounded, Icons.manage_search_rounded),
  reels('Reels', Icons.movie_outlined, Icons.movie_rounded),
  groups('Groups', Icons.groups_outlined, Icons.groups_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  const SocialSection(this.label, this.icon, this.activeIcon);
}

class SocialNavigationHeader extends StatelessWidget {
  final VoidCallback onGroups;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;

  const SocialNavigationHeader(
      {super.key,
      required this.onGroups,
      required this.onMessages,
      required this.onNotifications});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VeyroTheme.overlay(colors),
      child: Material(
        color: colors.surfaceContainerLow,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 1, 6, 1),
                child: Row(children: [
                  const Expanded(
                      child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: VeyroWordmark(size: 27))),
                  _action('Groups', Icons.groups_outlined, onGroups),
                  _action('Notifications', Icons.favorite_border_rounded,
                      onNotifications),
                  _action('Messages', Icons.send_outlined, onMessages),
                ]),
              )),
          const Divider(),
        ]),
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback tap) => IconButton(
        tooltip: label,
        onPressed: tap,
        icon: Icon(icon, size: 24),
      );
}

class SocialBottomBar extends StatelessWidget {
  final SocialSection selected;
  final ValueChanged<SocialSection> onSelect;
  final VoidCallback onCompose;
  final String? avatar;
  final String? name;

  const SocialBottomBar(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onCompose,
      this.avatar,
      this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VeyroTheme.overlay(colors),
      child: Material(
          color: colors.surfaceContainerLow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  _destination(context, SocialSection.home),
                  _destination(context, SocialSection.explore),
                  _tab(context,
                      label: 'Create',
                      active: false,
                      onTap: onCompose,
                      mark: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: VeyroTheme.orbit,
                            borderRadius: BorderRadius.circular(9)),
                        child: const SizedBox(
                            width: 32,
                            height: 27,
                            child: Icon(Icons.add_rounded,
                                color: VeyroTheme.midnight, size: 21)),
                      )),
                  _destination(context, SocialSection.reels),
                  _destination(context, SocialSection.profile),
                ]),
              ),
            ],
          )),
    );
  }

  Widget _destination(BuildContext context, SocialSection section) {
    final active = section == selected;
    final color = active
        ? context.veyroColors.primary
        : context.veyroColors.onSurfaceVariant;
    return _tab(
      context,
      label: section.label,
      active: active,
      onTap: () => onSelect(section),
      mark: section == SocialSection.profile
          ? DecoratedBox(
              decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: color)),
              child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: UserAvatar(imageUrl: avatar, name: name, radius: 10)))
          : Icon(active ? section.activeIcon : section.icon,
              color: color, size: 25),
    );
  }

  Widget _tab(BuildContext context,
          {required String label,
          required bool active,
          required VoidCallback onTap,
          required Widget mark}) =>
      Expanded(
          child: Semantics(
        label: label,
        button: true,
        selected: active,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
            onTap: onTap,
            child: SizedBox(
                height: 57,
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        mark,
                        const SizedBox(height: 3),
                        Text(label,
                            style: context.veyroText.labelSmall?.copyWith(
                                fontSize: 10,
                                color: active
                                    ? context.veyroColors.primary
                                    : context.veyroColors.onSurfaceVariant,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w700)),
                      ])),
                )))),
      ));
}

class SocialDesktopRail extends StatelessWidget {
  final SocialSection selected;
  final ValueChanged<SocialSection> onSelect;
  final VoidCallback onCompose;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final VoidCallback onSaved;
  final String? avatar;
  final String? name;
  final String? username;

  const SocialDesktopRail(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onCompose,
      required this.onMessages,
      required this.onNotifications,
      required this.onSaved,
      this.avatar,
      this.name,
      this.username});

  @override
  Widget build(BuildContext context) {
    final colors = context.veyroColors;
    final display =
        name?.trim().isNotEmpty == true ? name! : username ?? 'Your profile';
    return Material(
        color: colors.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: BorderDirectional(
                  end: BorderSide(color: colors.outlineVariant))),
          child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              children: [
                const Padding(
                    padding: EdgeInsetsDirectional.only(start: 6, bottom: 18),
                    child: VeyroWordmark(size: 29)),
                for (final section in [
                  SocialSection.home,
                  SocialSection.explore,
                  SocialSection.reels,
                  SocialSection.groups
                ])
                  _item(
                      context,
                      section.label,
                      section == selected ? section.activeIcon : section.icon,
                      () => onSelect(section),
                      active: section == selected),
                _item(context, 'Messages', Icons.send_outlined, onMessages),
                _item(context, 'Notifications', Icons.favorite_border_rounded,
                    onNotifications),
                _item(context, 'Saved posts', Icons.bookmark_border_rounded,
                    onSaved),
                const SizedBox(height: 10),
                FilledButton.icon(
                    onPressed: onCompose,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create')),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 9),
                Semantics(
                  label: 'Profile',
                  button: true,
                  selected: selected == SocialSection.profile,
                  onTap: () => onSelect(SocialSection.profile),
                  excludeSemantics: true,
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    selected: selected == SocialSection.profile,
                    selectedTileColor: colors.primaryContainer,
                    contentPadding:
                        const EdgeInsetsDirectional.only(start: 8, end: 6),
                    leading:
                        UserAvatar(imageUrl: avatar, name: display, radius: 16),
                    title: Text(display,
                        style: context.veyroText.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        username?.isNotEmpty == true ? '@$username' : 'Profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.veyroText.bodySmall),
                    onTap: () => onSelect(SocialSection.profile),
                  ),
                ),
              ]),
        ));
  }

  Widget _item(
      BuildContext context, String label, IconData icon, VoidCallback tap,
      {bool active = false}) {
    final colors = context.veyroColors;
    final foreground = active ? colors.onPrimaryContainer : colors.onSurface;
    return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Semantics(
          label: label,
          button: true,
          selected: active,
          onTap: tap,
          excludeSemantics: true,
          child: ListTile(
            dense: true,
            minTileHeight: 46,
            minLeadingWidth: 24,
            horizontalTitleGap: 10,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            selected: active,
            selectedTileColor: colors.primaryContainer,
            leading: Icon(icon,
                size: 23, color: active ? foreground : colors.onSurfaceVariant),
            title: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.veyroText.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w700)),
            onTap: tap,
          ),
        ));
  }
}
