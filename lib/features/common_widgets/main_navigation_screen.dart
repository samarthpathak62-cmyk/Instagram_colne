import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:instagram_clone/features/common_widgets/social_navigation_header.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:instagram_clone/features/feed/presentation/screens/feed_screen.dart';
import 'package:instagram_clone/features/groups/presentation/groups_screen.dart';
import 'package:instagram_clone/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/create_post_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/video_explore_tab.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  SocialSection _selected = SocialSection.home;
  bool _composing = false;
  final _visited = <SocialSection>{SocialSection.home};
  FeedComposeMode _composeMode = FeedComposeMode.post;

  void _compose([FeedComposeMode mode = FeedComposeMode.post]) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _composeMode = mode;
      _composing = true;
    });
  }

  void _select(SocialSection section) {
    if (!_composing && _selected == section) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = section;
      _visited.add(section);
      _composing = false;
    });
  }

  void _open(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  void _openMessages(User user) => _open((_) => BlocProvider<ChatBloc>(
        create: (_) => di.sl<ChatBloc>(),
        child: ChatsListScreen(currentUser: user),
      ));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! Authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    final desktop = MediaQuery.sizeOf(context).width >= 1040;
    // Keep the content in the same tree slot when the window is resized so
    // scroll positions, video/Groups state and the drafts aren't recreated.
    return PopScope<Object?>(
        canPop: !_composing && _selected == SocialSection.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && (_composing || _selected != SocialSection.home)) {
            _select(_composing ? _selected : SocialSection.home);
          }
        },
        child: Scaffold(
          bottomNavigationBar: desktop ||
                  _composing ||
                  MediaQuery.viewInsetsOf(context).bottom > 0
              ? null
              : SocialBottomBar(
                  selected: _selected,
                  onSelect: _select,
                  onCompose: _compose,
                  avatar: user.profilePictureUrl,
                  name: user.name ?? user.username),
          body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (desktop)
              SizedBox(
                  width: 210,
                  child: SafeArea(
                      right: false,
                      child: SocialDesktopRail(
                        selected: _selected,
                        onSelect: _select,
                        onCompose: _compose,
                        onMessages: () => _openMessages(user),
                        onNotifications: () =>
                            _open((_) => const NotificationsScreen()),
                        onSaved: () =>
                            _open((_) => FavoritesScreen(userId: user.id)),
                        avatar: user.profilePictureUrl,
                        name: user.name,
                        username: user.username,
                      ))),
            Expanded(
                key: const ValueKey('social-content'),
                child: Column(children: [
                  if (!desktop &&
                      !_composing &&
                      _selected == SocialSection.home)
                    SocialNavigationHeader(
                        onGroups: () => _select(SocialSection.groups),
                        onMessages: () => _openMessages(user),
                        onNotifications: () =>
                            _open((_) => const NotificationsScreen())),
                  Expanded(
                      key: const ValueKey('social-pages'),
                      child: SafeArea(
                        top: desktop,
                        bottom: desktop || _composing,
                        child: _pages(user),
                      )),
                ])),
          ]),
        ));
  }

  Widget _pages(User user) => IndexedStack(
        index: _composing ? SocialSection.values.length : _selected.index,
        children: [
          TickerMode(
              enabled: !_composing && _selected == SocialSection.home,
              child: FeedScreen(
                  onCompose: _compose,
                  onGroups: () => _select(SocialSection.groups))),
          _visited.contains(SocialSection.explore)
              ? SearchScreen(onGroups: () => _select(SocialSection.groups))
              : const SizedBox.shrink(),
          !_composing && _selected == SocialSection.reels
              ? VideoExploreTab(onCreate: () => _compose(FeedComposeMode.reel))
              : const SizedBox.shrink(),
          _visited.contains(SocialSection.groups)
              ? const GroupsScreen()
              : const SizedBox.shrink(),
          !_composing && _selected == SocialSection.profile
              ? ProfileScreen.withProviders(user.id)
              : const SizedBox.shrink(),
          IndexedStack(
              index: _composeMode.index,
              sizing: StackFit.expand,
              children: [
                for (final mode in FeedComposeMode.values)
                  ExcludeFocus(
                      excluding: !_composing || _composeMode != mode,
                      child: CreatePostScreen(
                        photoMode: mode == FeedComposeMode.photo,
                        reelMode: mode == FeedComposeMode.reel,
                        onCreated: (_) {
                          if (_composing && _composeMode == mode)
                            _select(mode == FeedComposeMode.reel
                                ? SocialSection.reels
                                : SocialSection.home);
                        },
                        onClose: () => _select(_selected),
                      )),
              ]),
        ],
      );
}
