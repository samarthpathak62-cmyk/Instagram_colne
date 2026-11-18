import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:instagram_clone/features/common_widgets/social_navigation_header.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
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
    if (auth is! Authenticated)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = auth.user;
    final large = MediaQuery.sizeOf(context).width >= 1160;
    return Scaffold(
        body: Column(children: [
      SocialNavigationHeader(
        selected: _selected,
        onSelect: _select,
        onCompose: _compose,
        onSearch: () => _open((_) => const SearchScreen()),
        onMessages: () => _openMessages(user),
        onNotifications: () => _open((_) => const NotificationsScreen()),
      ),
      Expanded(
          child: SafeArea(
              top: false,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1352),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (large)
                        SizedBox(width: 212, child: _shortcuts(context, user)),
                      Expanded(child: _pages(user)),
                    ]),
              )))),
    ]));
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
              ? const SearchScreen()
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

  Widget _shortcuts(BuildContext context, User user) {
    final colors = context.veyroColors;
    Widget entry(String title, IconData icon, VoidCallback onTap) => ListTile(
          dense: true,
          contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 5),
          minLeadingWidth: 32,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          leading: CircleAvatar(
              radius: 16,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Icon(icon, size: 18)),
          title: Text(title, style: context.veyroText.labelLarge),
          onTap: onTap,
        );
    final name = user.name?.trim();
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 20, 0, 12),
        children: [
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            leading: UserAvatar(
                imageUrl: user.profilePictureUrl,
                name: name ?? user.username,
                radius: 19),
            title: Text(
                name?.isNotEmpty == true
                    ? name!
                    : user.username ?? 'Your profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.veyroText.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            subtitle:
                Text('View your profile', style: context.veyroText.bodySmall),
            onTap: () => _select(SocialSection.profile),
          ),
          const SizedBox(height: 10),
          const Divider(indent: 8, endIndent: 8),
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 3, 5),
              child: Text('Shortcuts',
                  style: context.veyroText.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800))),
          entry('Saved posts', Icons.bookmark_outline_rounded,
              () => _open((_) => FavoritesScreen(userId: user.id))),
          entry('Communities', Icons.groups_outlined,
              () => _select(SocialSection.groups)),
          entry('Watch videos', Icons.play_circle_outline_rounded,
              () => _select(SocialSection.reels)),
          entry('Inbox', Icons.chat_bubble_outline_rounded,
              () => _openMessages(user)),
        ]);
  }
}
