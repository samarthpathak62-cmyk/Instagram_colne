import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
import 'package:instagram_clone/features/notifications/domain/entities/notification.dart';
import 'package:instagram_clone/features/notifications/presentation/bloc/activity_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthBloc>().state is Authenticated) {
      context.read<ActivityCubit>().refresh(quiet: true);
    }
  }

  Future<void> _perform(Future<bool> action) async {
    if (!await action && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn’t update notifications. Try again.')));
    }
  }

  Future<void> _open(Notification item) async {
    if (_opening) return;
    _opening = true;
    try {
      if (!item.isRead)
        await _perform(context.read<ActivityCubit>().markRead(item.id));
      if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
      if (item.type == NotificationType.follow && item.actorId != null) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ProfileScreen.withProviders(item.actorId!)));
      } else if ((item.type == NotificationType.like ||
              item.type == NotificationType.comment) &&
          item.resourceId != null) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PostDetailScreen(postId: item.resourceId!)));
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthBloc>().state is! Authenticated) {
      return const Scaffold(
          body: Center(child: Text('Log in to see your notifications.')));
    }
    final state = context.watch<ActivityCubit>().state;
    final activity = context.read<ActivityCubit>();
    final newItems = state.items.where((item) => !item.isRead).toList();
    final earlier = state.items.where((item) => item.isRead).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        IconButton(
            tooltip: 'Refresh notifications',
            onPressed:
                state.loading || state.updating ? null : activity.refresh,
            icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: state.items.isEmpty && state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty && state.error != null
                ? VeyroEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Notifications unavailable',
                    description: state.error!,
                    action: FilledButton(
                        onPressed: activity.refresh,
                        child: const Text('Retry')))
                : state.items.isEmpty
                    ? const VeyroEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'You’re all caught up',
                        description:
                            'Follows, reactions and comments will show up here.')
                    : RefreshIndicator(
                        onRefresh: activity.refresh,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (state.loading)
                              const SliverToBoxAdapter(
                                  child: LinearProgressIndicator(minHeight: 2)),
                            if (newItems.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                  child: _heading('New',
                                      action: TextButton(
                                          onPressed: state.updating
                                              ? null
                                              : () => _perform(
                                                  activity.markAllRead()),
                                          child:
                                              const Text('Mark all as read')))),
                              SliverList.builder(
                                  itemCount: newItems.length,
                                  itemBuilder: (context, index) =>
                                      _tile(newItems[index], state.updating)),
                            ],
                            if (earlier.isNotEmpty) ...[
                              SliverToBoxAdapter(child: _heading('Earlier')),
                              SliverList.builder(
                                  itemCount: earlier.length,
                                  itemBuilder: (context, index) =>
                                      _tile(earlier[index], state.updating)),
                            ],
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 20)),
                          ],
                        )),
      )),
    );
  }

  Widget _heading(String label, {Widget? action}) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 3),
        child: Row(children: [
          Expanded(child: Text(label, style: context.veyroText.titleMedium)),
          if (action != null)
            Flexible(
                flex: 2,
                child: Align(
                    alignment: AlignmentDirectional.centerEnd, child: action)),
        ]),
      );

  Widget _tile(Notification item, bool updating) {
    final colors = context.veyroColors;
    final event = switch (item.type) {
      NotificationType.follow => Icons.person_add_alt_1_outlined,
      NotificationType.like => Icons.favorite_rounded,
      NotificationType.comment => Icons.chat_bubble_outline_rounded,
      _ => Icons.notifications_none_rounded,
    };
    return Material(
      key: ValueKey(item.id),
      color: item.isRead ? colors.surface : colors.surfaceContainer,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 7, 4),
        leading: Badge(
            alignment: AlignmentDirectional.bottomEnd,
            offset: const Offset(4, 3),
            backgroundColor: colors.primaryContainer,
            padding: const EdgeInsets.all(3),
            label: Icon(event, size: 13, color: colors.onPrimaryContainer),
            child: UserAvatar(
                name: item.senderUsername,
                imageUrl: item.senderProfilePictureUrl,
                radius: 21)),
        title: Text.rich(
            TextSpan(children: [
              if (item.senderUsername != null)
                TextSpan(
                    text: '@${item.senderUsername} ',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                  text: item.message.isEmpty ? 'New activity' : item.message),
            ]),
            style: context.veyroText.bodyMedium),
        subtitle: Text(timeago.format(item.createdAt),
            style: context.veyroText.bodySmall),
        onTap: updating ||
                (item.isRead && item.resourceId == null && item.actorId == null)
            ? null
            : () => _open(item),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!item.isRead)
            Semantics(
                label: 'Unread',
                child: Icon(Icons.circle, size: 7, color: colors.primary)),
          IconButton(
              tooltip: 'Dismiss notification',
              icon: const Icon(Icons.close_rounded, size: 19),
              onPressed: updating
                  ? null
                  : () =>
                      _perform(context.read<ActivityCubit>().dismiss(item.id))),
        ]),
      ),
    );
  }
}
