import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:instagram_clone/features/common_widgets/app_bar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/feed/presentation/screens/feed_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/create_post_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/video_explore_tab.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_box_outlined),
      selectedIcon: Icon(Icons.add_box_rounded),
      label: 'Create',
    ),
    NavigationDestination(
      icon: Icon(Icons.video_collection_outlined),
      selectedIcon: Icon(Icons.video_collection_rounded),
      label: 'Reels',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];
  int _selected = 0;

  void _select(int index) {
    if (_selected == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selected = index);
  }

  void _openMessages(User user) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<ChatBloc>(
            create: (_) => di.sl<ChatBloc>(),
            child: ChatsListScreen(currentUser: user),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! Authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colors = context.veyroColors;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 880 && size.height >= 520;
    final pages = IndexedStack(
      index: _selected,
      children: [
        Scaffold(
          appBar: CustomAppBar(
            title: wide ? 'Home' : null,
            onMessagesTap: () => _openMessages(auth.user),
          ),
          body: const FeedScreen(),
        ),
        CreatePostScreen(
            onCreated: () => _select(0), onClose: () => _select(0)),
        const VideoExploreTab(),
        ProfileScreen.withProviders(auth.user.id),
      ],
    );
    return Scaffold(
      body: SafeArea(
        bottom: wide,
        child: Row(
          children: [
            if (wide) ...[
              _buildSidebar(context),
              VerticalDivider(
                  width: 1, thickness: 1, color: colors.outlineVariant),
            ],
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: pages,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: _select,
                destinations: _destinations,
              ),
            ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final colors = context.veyroColors;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: SizedBox(
        width: 208,
        child: Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(15, 17, 15, 11),
                child: VeyroWordmark(size: 27),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Expanded(
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 208,
                backgroundColor: colors.surfaceContainerLow,
                selectedIndex: _selected,
                onDestinationSelected: _select,
                useIndicator: true,
                indicatorColor: colors.primaryContainer,
                selectedIconTheme:
                    IconThemeData(color: colors.onPrimaryContainer),
                unselectedIconTheme:
                    IconThemeData(color: colors.onSurfaceVariant),
                selectedLabelTextStyle: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                destinations: [
                  for (final item in _destinations)
                    NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 22),
              child: VeyroTagline(),
            ),
          ],
        ),
      ),
    );
  }
}
