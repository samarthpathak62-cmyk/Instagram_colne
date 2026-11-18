// lib/features/common_widgets/app_bar.dart

import 'package:flutter/material.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart'; // Added import for AuthBloc
import 'package:flutter_bloc/flutter_bloc.dart'; // Added import for BlocProvider
import 'package:instagram_clone/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:instagram_clone/features/notifications/presentation/screens/notifications_screen.dart'; // Added import for NotificationsScreen

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final bool showDefaultActions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMessagesTap; // New callback for messages icon

  const CustomAppBar({
    Key? key,
    this.title,
    this.actions,
    this.centerTitle = false,
    this.leading,
    this.showDefaultActions = true,
    this.showBackButton = false,
    this.onBackPressed,
    this.onMessagesTap, // Add to constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultActions = [
      //
      // _buildAppBarIcon(
      //   icon: Icons.add_box_outlined,
      //   onTap: () {
      //     Navigator.of(context).push(
      //       MaterialPageRoute(
      //         builder: (_) => const CreatePostScreen(),
      //       ),
      //     );
      //   },
      // ),
      // const SizedBox(width: 8),

      // Activity/Notifications Icon
      _buildAppBarIcon(
        icon: Icons.favorite_border,
        onTap: () {
          final authState = BlocProvider.of<AuthBloc>(context).state;
          if (authState is Authenticated) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FavoritesScreen(userId: authState.user.id),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('You must be logged in to view favorites.')),
            );
          }
        },
      ),

      const SizedBox(width: 8),

      // Messages Icon
      _buildAppBarIcon(
        icon: Icons.send_outlined,
        onTap: onMessagesTap ?? () {}, // Use the callback if provided
        rotation: 0.3, // Instagram's signature rotation
      ),

      const SizedBox(width: 8),

      // Explore/Search Icon
      _buildAppBarIcon(
        icon: Icons.search,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            ),
          );
        },
      ),
      const SizedBox(width: 8),

      // Notifications Icon
      _buildAppBarIcon(
        icon: Icons.notifications_none,
        onTap: () {
          final authState = BlocProvider.of<AuthBloc>(context).state;
          if (authState is Authenticated) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('You must be logged in to view notifications.')),
            );
          }
        },
      ),
      const SizedBox(width: 8),
    ];

    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFDBDBDB),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Leading widget or back button
              if (showBackButton || leading != null)
                leading ??
                    _buildAppBarIcon(
                      icon: Icons.arrow_back,
                      onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                    ),

              if (showBackButton || leading != null) const SizedBox(width: 16),

              // Title
              if (!centerTitle)
                Expanded(
                  child: Text(
                    title ?? 'Instagram',
                    style: const TextStyle(
                      fontFamily: 'Billabong',
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF262626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              if (centerTitle) ...[
                const Spacer(),
                Text(
                  title ?? 'Instagram',
                  style: const TextStyle(
                    fontFamily: 'Billabong',
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF262626),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
              ],

              // Actions
              if (showDefaultActions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions != null
                      ? [...actions!, ...defaultActions]
                      : defaultActions,
                )
              else if (actions != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon({
    required IconData icon,
    required VoidCallback onTap,
    double? rotation,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: rotation != null
            ? Transform.rotate(
                angle: rotation,
                child: Icon(
                  icon,
                  size: 26,
                  color: const Color(0xFF262626),
                ),
              )
            : Icon(
                icon,
                size: 26,
                color: const Color(0xFF262626),
              ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

// Instagram-style Search AppBar
class InstagramSearchAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final TextEditingController? searchController;
  final Function(String)? onSearchChanged;
  final VoidCallback? onBackPressed;

  const InstagramSearchAppBar({
    Key? key,
    this.searchController,
    this.onSearchChanged,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFDBDBDB),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 26,
                    color: Color(0xFF262626),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E8E8E),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Color(0xFF8E8E8E),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF262626),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
