import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/notifications/domain/entities/notification.dart';
import 'package:instagram_clone/features/notifications/domain/repositories/notification_repository.dart';

class ActivityState extends Equatable {
  final List<Notification> items;
  final bool loading;
  final bool updating;
  final String? error;

  const ActivityState(
      {this.items = const [],
      this.loading = true,
      this.updating = false,
      this.error});

  int get unreadCount => items.where((item) => !item.isRead).length;

  @override
  List<Object?> get props => [items, loading, updating, error];
}

/// The bell/menu badge and the notification list share the signed-in state.
/// Reads and writes are serialized so a stale poll cannot restore a read badge.
class ActivityCubit extends Cubit<ActivityState> {
  final NotificationRepository repository;
  final String userId;
  Future<void>? _reading;
  StreamSubscription<void>? _subscription;
  bool _started = false;
  bool _closing = false;
  bool _refreshPending = false;

  ActivityCubit({required this.repository, required this.userId})
      : super(const ActivityState());

  void start() {
    if (_started || _closing) return;
    _started = true;
    unawaited(refresh());
    _subscription = repository.watchChanges(userId).listen(
          // Reload the actor join rather than rendering a raw WAL row.
          (_) => unawaited(refresh(quiet: true)), onError: (Object _) {},
        );
  }

  Future<void> refresh({bool quiet = false}) {
    if (_closing) return Future.value();
    if (state.updating || _reading != null) {
      // An event received while REST is in flight may be newer than that
      // snapshot. Coalesce the changes into a follow-up read.
      _refreshPending = true;
      return _reading ?? Future.value();
    }
    return _reading = _read(quiet).whenComplete(() {
      _reading = null;
      if (_refreshPending && !state.updating && !_closing)
        unawaited(refresh(quiet: true));
    });
  }

  Future<void> _read(bool quiet) async {
    if (!quiet) emit(ActivityState(items: state.items));
    do {
      _refreshPending = false;
      final result = await repository.getNotifications(userId);
      if (_closing) return;
      result.fold(
        (_) => emit(ActivityState(
            items: state.items,
            loading: false,
            updating: state.updating,
            error: quiet && state.items.isNotEmpty
                ? null
                : 'Couldn’t load notifications. Try again.')),
        (rows) => emit(ActivityState(
            items: List.unmodifiable(rows),
            loading: false,
            updating: state.updating)),
      );
      quiet = true;
    } while (_refreshPending && !state.updating);
  }

  Future<bool> markRead(String id) => _write(
      () => repository.markAsRead(id),
      (rows) => [
            for (final row in rows)
              row.id == id ? row.copyWith(isRead: true) : row
          ]);

  Future<bool> markAllRead() => _write(() => repository.markAllAsRead(userId),
      (rows) => [for (final row in rows) row.copyWith(isRead: true)]);

  Future<bool> dismiss(String id) => _write(
      () => repository.deleteNotification(id),
      (rows) => rows.where((row) => row.id != id).toList());

  Future<bool> _write(Future<Either<Failure, void>> Function() operation,
      List<Notification> Function(List<Notification>) update) async {
    if (_closing || state.updating) return false;
    emit(ActivityState(
        items: state.items, loading: state.loading, updating: true));
    await _reading;
    if (_closing) return false;
    final result = await operation();
    if (_closing) return false;
    final success = result.isRight();
    emit(ActivityState(
        items: success ? List.unmodifiable(update(state.items)) : state.items,
        loading: false,
        error: success ? null : state.error));
    if (_refreshPending) {
      _refreshPending = false;
      unawaited(refresh(quiet: true));
    }
    return success;
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _subscription?.cancel();
    return super.close();
  }
}
