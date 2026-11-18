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
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/feed/presentation/screens/feed_screen.dart';
import 'package:instagram_clone/features/groups/presentation/groups_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/create_post_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/video_explore_tab.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const _home = 0,
      _explore = 1,
      _reels = 2,
      _groups = 3,
      _profile = 4,
      _create = 5;
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'Explore',
    ),
    NavigationDestination(
      icon: Icon(Icons.video_collection_outlined),
      selectedIcon: Icon(Icons.video_collection_rounded),
      label: 'Reels',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups_rounded),
      label: 'Groups',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];
  int _selected = _home;
  int _previous = _home;
  bool _exploreVisited = false;
  bool _groupsVisited = false;

  int get _navIndex => _selected == _create ? _previous : _selected;
  FeedComposeMode _composeMode = FeedComposeMode.post;

  void _compose([FeedComposeMode mode = FeedComposeMode.post]) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (_selected != _create) _previous = _selected;
      _composeMode = mode;
      _selected = _create;
    });
  }

  void _select(int index) {
    if (_selected == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = index;
      if (index == _explore) _exploreVisited = true;
      if (index == _groups) _groupsVisited = true;
    });
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
            actions: [
              if (!wide)
                IconButton.filledTonal(
                  tooltip: 'Create a post',
                  onPressed: _compose,
                  icon: const Icon(Icons.add_rounded),
                )
            ],
          ),
          body: TickerMode(
              enabled: _selected == _home,
              child: FeedScreen(
                  onCompose: _compose, onGroups: () => _select(_groups))),
        ),
        _exploreVisited ? const SearchScreen() : const SizedBox.shrink(),
        _selected == _reels
            ? VideoExploreTab(onCreate: () => _compose(FeedComposeMode.reel))
            : const SizedBox.shrink(),
        _groupsVisited ? const GroupsScreen() : const SizedBox.shrink(),
        _selected == _profile
            ? ProfileScreen.withProviders(auth.user.id)
            : const SizedBox.shrink(),
        IndexedStack(
          index: _composeMode.index,
          sizing: StackFit.expand,
          children: [
            for (final mode in FeedComposeMode.values)
              ExcludeFocus(
                excluding: _selected != _create || _composeMode != mode,
                child: CreatePostScreen(
                  photoMode: mode == FeedComposeMode.photo,
                  reelMode: mode == FeedComposeMode.reel,
                  onCreated: (_) {
                    if (_selected == _create && _composeMode == mode)
                      _select(mode == FeedComposeMode.reel ? _reels : _home);
                  },
                  onClose: () => _select(_previous),
                ),
              ),
          ],
        ),
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
                  constraints: const BoxConstraints(maxWidth: 1160),
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
                selectedIndex: _navIndex,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 15),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _compose,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create a post'),
                  )),
            ),
            const Divider(indent: 16, endIndent: 16),
            Expanded(
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 208,
                backgroundColor: colors.surfaceContainerLow,
                selectedIndex: _navIndex,
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
              child: FittedBox(fit: BoxFit.scaleDown, child: VeyroTagline()),
            ),
          ],
        ),
      ),
    );
  }
}
