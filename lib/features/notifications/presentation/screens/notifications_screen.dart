import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/notifications/domain/entities/notification.dart';
import 'package:instagram_clone/features/notifications/domain/repositories/notification_repository.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    return auth is Authenticated
        ? _Activity(userId: auth.user.id)
        : Scaffold(
            appBar: AppBar(title: const Text('Notifications')),
            body:
                const Center(child: Text('Log in to see your notifications.')));
  }
}

class _Activity extends StatefulWidget {
  final String userId;
  const _Activity({required this.userId});

  @override
  State<_Activity> createState() => _ActivityState();
}

class _ActivityState extends State<_Activity> {
  final _repo = sl<NotificationRepository>();
  bool _busy = false;
  String? _error;
  List<Notification> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _repo.getNotifications(widget.userId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold(
          (failure) => _error = failure.message, (rows) => _rows = rows);
    });
  }

  Future<bool> _mutate(Future<Either<Failure, void>> action,
      List<Notification> Function() update) async {
    setState(() => _busy = true);
    final result = await action;
    if (!mounted) return false;
    setState(() => _busy = false);
    return result.fold((failure) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
      return false;
    }, (_) {
      setState(() => _rows = update());
      return true;
    });
  }

  Future<void> _open(Notification item) async {
    if (_busy) return;
    if (!item.isRead) {
      await _mutate(
          _repo.markAsRead(item.id),
          () => _rows
              .map(
                  (row) => row.id == item.id ? row.copyWith(isRead: true) : row)
              .toList());
    }
    if (!mounted) return;
    if (item.type == NotificationType.follow && item.actorId != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ProfileScreen.withProviders(item.actorId!)));
    } else if ((item.type == NotificationType.like ||
            item.type == NotificationType.comment) &&
        item.resourceId != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(postId: item.resourceId!)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [
          IconButton(
              tooltip: 'Refresh notifications',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'Mark all as read',
              onPressed: _busy || !_rows.any((row) => !row.isRead)
                  ? null
                  : () => _mutate(
                      _repo.markAllAsRead(widget.userId),
                      () => _rows
                          .map((row) => row.copyWith(isRead: true))
                          .toList()),
              icon: const Icon(Icons.done_all_rounded)),
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: _rows.isEmpty && _busy
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? CustomErrorWidget(message: _error!, onRetry: _load)
                  : _rows.isEmpty
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                  'New follows, likes and comments will appear here.',
                                  textAlign: TextAlign.center)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _rows.length,
                            itemBuilder: (context, index) =>
                                _tile(_rows[index]),
                          )),
        )),
      );

  Widget _tile(Notification item) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey(item.id),
      color: item.isRead ? null : colors.surfaceContainerHigh,
      child: ListTile(
        leading: UserAvatar(imageUrl: item.senderProfilePictureUrl, radius: 19),
        title: Text([
          if (item.senderUsername != null) '@${item.senderUsername}',
          item.message.isEmpty ? 'New activity' : item.message
        ].join(' ')),
        subtitle: Text(timeago.format(item.createdAt)),
        onTap: _busy ||
                (item.isRead && item.resourceId == null && item.actorId == null)
            ? null
            : () => _open(item),
        trailing: IconButton(
            tooltip: 'Dismiss notification',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: _busy
                ? null
                : () => _mutate(_repo.deleteNotification(item.id),
                    () => _rows.where((row) => row.id != item.id).toList())),
      ),
    );
  }
}
