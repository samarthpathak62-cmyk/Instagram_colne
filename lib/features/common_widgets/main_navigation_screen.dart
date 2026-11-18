import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:instagram_clone/features/common_widgets/social_navigation_header.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/screens/feed_screen.dart';
import 'package:instagram_clone/features/groups/presentation/groups_screen.dart';
import 'package:instagram_clone/features/notifications/presentation/bloc/activity_cubit.dart';
import 'package:instagram_clone/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/screens/create_post_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/create_reel_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/video_explore_tab.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';
import 'package:instagram_clone/features/story/presentation/screens/create_story_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  SocialSection _selected = SocialSection.home;
  int _reelRevision = 0;
  final _visited = <SocialSection>{SocialSection.home};
  bool _creating = false;

  late final Timer _badgePoll;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshBadges);
    _badgePoll = Timer.periodic(const Duration(seconds: 25), (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) _refreshBadges();
    });
  }

  @override
  void dispose() {
    _badgePoll.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshBadges() {
    if (!mounted) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated) return;
    unawaited(context.read<ActivityCubit>().refresh(quiet: true));
    context
        .read<ChatBloc>()
        .add(LoadChatsEvent(userId: auth.user.id, quiet: true));
  }

  Future<void> _showCreate() async {
    if (_creating) return;
    _creating = true;
    FeedComposeMode? mode;
    try {
      mode = await showModalBottomSheet<FeedComposeMode>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 480),
        builder: (_) => const _CreateMenu(),
      );
    } finally {
      _creating = false;
    }
    if (mounted && mode != null) await _compose(mode);
  }

  Future<void> _compose(FeedComposeMode mode) async {
    if (_creating) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _creating = true;
    try {
      switch (mode) {
        case FeedComposeMode.reel:
          final reel = await CreateReelScreen.open(context);
          if (!mounted || reel == null) return;
          unawaited(context.read<FeedCubit>().refresh());
          setState(() {
            _reelRevision++;
            _selected = SocialSection.reels;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Reel published')));
        case FeedComposeMode.story:
          final created = await CreateStoryScreen.open(context);
          if (!mounted || created != true) return;
          _select(SocialSection.home);
          unawaited(context.read<FeedCubit>().refresh());
        case FeedComposeMode.post:
        case FeedComposeMode.photo:
          final post = await Navigator.of(context).push<Post>(MaterialPageRoute(
            builder: (_) =>
                CreatePostScreen(photoMode: mode == FeedComposeMode.photo),
          ));
          if (mounted && post != null) _select(SocialSection.home);
      }
    } finally {
      _creating = false;
    }
  }

  void _select(SocialSection section) {
    if (_selected == section) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selected = section;
      _visited.add(section);
    });
  }

  void _open(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  void _openMessages(User user) =>
      _open((_) => ChatsListScreen(currentUser: user));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! Authenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    final unreadNotifications =
        context.select((ActivityCubit cubit) => cubit.state.unreadCount);
    final unreadChats = context.select((ChatBloc bloc) {
      final state = bloc.state;
      return state is ChatsLoaded
          ? state.chats.where((chat) => chat.hasUnreadMessages).length
          : 0;
    });
    final desktop = MediaQuery.sizeOf(context).width >= 1040;
    // Keep the content in the same tree slot when the window is resized so
    // scroll positions and already-open tabs survive the layout change.
    return PopScope<Object?>(
        canPop: _selected == SocialSection.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selected != SocialSection.home)
            _select(SocialSection.home);
        },
        child: Scaffold(
          bottomNavigationBar:
              desktop || MediaQuery.viewInsetsOf(context).bottom > 0
                  ? null
                  : SocialBottomBar(
                      selected: _selected,
                      onSelect: _select,
                      onCompose: _showCreate,
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
                        unreadNotifications: unreadNotifications,
                        unreadChats: unreadChats,
                        onSelect: _select,
                        onCompose: _showCreate,
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
                  if (!desktop && _selected == SocialSection.home)
                    SocialNavigationHeader(
                        unreadNotifications: unreadNotifications,
                        unreadChats: unreadChats,
                        onGroups: () => _select(SocialSection.groups),
                        onMessages: () => _openMessages(user),
                        onNotifications: () =>
                            _open((_) => const NotificationsScreen())),
                  Expanded(
                      key: const ValueKey('social-pages'),
                      child: SafeArea(
                        top: desktop,
                        bottom: desktop,
                        child: _pages(user),
                      )),
                ])),
          ]),
        ));
  }

  Widget _pages(User user) => IndexedStack(index: _selected.index, children: [
        TickerMode(
            enabled: _selected == SocialSection.home,
            child: FeedScreen(
                onCompose: _compose,
                onGroups: () => _select(SocialSection.groups))),
        _visited.contains(SocialSection.explore)
            ? SearchScreen(onGroups: () => _select(SocialSection.groups))
            : const SizedBox.shrink(),
        _selected == SocialSection.reels
            ? VideoExploreTab(
                key: ValueKey(_reelRevision),
                onCreate: () => _compose(FeedComposeMode.reel))
            : const SizedBox.shrink(),
        _visited.contains(SocialSection.groups)
            ? const GroupsScreen()
            : const SizedBox.shrink(),
        _selected == SocialSection.profile
            ? ProfileScreen.withProviders(user.id)
            : const SizedBox.shrink(),
      ]);
}

class _CreateMenu extends StatelessWidget {
  const _CreateMenu();

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 10, 8),
                child: Text('Create', style: context.veyroText.titleLarge)),
            _item(context, FeedComposeMode.post, Icons.grid_on_rounded, 'Post',
                'Share text or photos'),
            _item(context, FeedComposeMode.reel, Icons.movie_outlined, 'Reel',
                'Share a video'),
            _item(
                context,
                FeedComposeMode.story,
                Icons.add_circle_outline_rounded,
                'Story',
                'Share for 24 hours'),
          ],
        ),
      ));

  Widget _item(BuildContext context, FeedComposeMode mode, IconData icon,
      String title, String subtitle) {
    final colors = context.veyroColors;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(10, 4, 8, 4),
      leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Icon(icon, size: 22)),
      title: Text(title, style: context.veyroText.titleMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).pop(mode),
    );
  }
}
