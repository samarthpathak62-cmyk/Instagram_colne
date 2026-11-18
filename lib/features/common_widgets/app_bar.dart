import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:instagram_clone/features/notifications/presentation/screens/notifications_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const _height = 64.0;

  final String? title;
  final List<Widget> actions;
  final bool showDefaultActions;
  final VoidCallback? onMessagesTap;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions = const [],
    this.showDefaultActions = true,
    this.onMessagesTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(_height + 1);

  @override
  Widget build(BuildContext context) {
    final isTight = MediaQuery.sizeOf(context).width < 360;
    final auth = showDefaultActions ? context.watch<AuthBloc>().state : null;
    final userId = auth is Authenticated ? auth.user.id : null;
    final colors = context.veyroColors;
    void open(Widget page) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );

    return AppBar(
      toolbarHeight: _height,
      titleSpacing: title == null ? 9 : NavigationToolbar.kMiddleSpacing,
      centerTitle: false,
      title: title == null
          ? VeyroWordmark(size: isTight ? 21 : 25)
          : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
      actionsPadding: const EdgeInsetsDirectional.only(end: 6),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: colors.outlineVariant),
      ),
      actions: [
        ...actions,
        if (showDefaultActions) ...[
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => open(const SearchScreen()),
          ),
          if (onMessagesTap != null)
            IconButton(
              tooltip: 'Messages',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: onMessagesTap,
            ),
          if (userId != null) ...[
            if (isTight)
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) {
                  if (action == 'saved') {
                    open(FavoritesScreen(userId: userId));
                  } else {
                    open(const NotificationsScreen());
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'saved', child: Text('Saved posts')),
                  PopupMenuItem(
                      value: 'notifications', child: Text('Notifications')),
                ],
              )
            else ...[
              IconButton(
                tooltip: 'Saved posts',
                icon: const Icon(Icons.bookmark_outline_rounded),
                onPressed: () => open(FavoritesScreen(userId: userId)),
              ),
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => open(const NotificationsScreen()),
              ),
            ],
          ],
        ],
      ],
    );
  }
}
