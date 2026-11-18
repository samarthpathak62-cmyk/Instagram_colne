import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/notifications/domain/entities/notification.dart';
import 'package:instagram_clone/features/notifications/domain/repositories/notification_repository.dart';
import 'package:instagram_clone/features/notifications/presentation/bloc/activity_cubit.dart';

Notification _activity(String id, {bool read = false}) => Notification(
      id: id,
      userId: 'me',
      actorId: 'friend',
      senderUsername: 'veyro_friend',
      type: NotificationType.comment,
      resourceId: 'post',
      message: 'commented on your post.',
      isRead: read,
      createdAt: DateTime.utc(2026, 11, 18),
    );

class _ActivityRepository implements NotificationRepository {
  final changes = StreamController<void>.broadcast();
  List<Notification> rows = [_activity('initial')];
  Completer<Either<Failure, List<Notification>>>? waitForRead;
  bool rejectReadUpdates = false;

  @override
  Future<Either<Failure, List<Notification>>> getNotifications(
      String userId) async {
    expect(userId, 'me');
    final pending = waitForRead;
    waitForRead = null;
    if (pending != null) return pending.future;
    return Right(List.of(rows));
  }

  @override
  Stream<void> watchChanges(String userId) => changes.stream;

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    if (rejectReadUpdates) return const Left(ServerFailure(message: 'Offline'));
    rows = [
      for (final row in rows)
        row.id == notificationId ? row.copyWith(isRead: true) : row
    ];
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markAllAsRead(String userId) async {
    rows = [for (final row in rows) row.copyWith(isRead: true)];
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteNotification(
      String notificationId) async {
    rows.removeWhere((row) => row.id == notificationId);
    return const Right(null);
  }
}

void main() {
  late _ActivityRepository repository;
  late ActivityCubit activity;

  setUp(() {
    repository = _ActivityRepository();
    activity = ActivityCubit(repository: repository, userId: 'me');
  });
  tearDown(() async {
    await activity.close();
    await repository.changes.close();
  });

  test('live update during a snapshot is re-fetched without losing its badge',
      () async {
    final first = Completer<Either<Failure, List<Notification>>>();
    repository.waitForRead = first;
    final ready = activity.stream.firstWhere((state) => state.unreadCount == 2);
    activity.start();
    final oldRows = [...repository.rows];
    repository.rows = [_activity('incoming'), ...oldRows];
    repository.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    first.complete(Right(oldRows));
    final hydrated = await ready;
    expect(hydrated.items.map((item) => item.id), ['incoming', 'initial']);
    expect(hydrated.items.first.senderUsername, 'veyro_friend');
  });

  test('read and dismiss keep the list and unread badge in sync', () async {
    repository.rows = [_activity('initial'), _activity('second')];
    await activity.refresh();
    expect(activity.state.unreadCount, 2);
    repository.rejectReadUpdates = true;
    expect(await activity.markRead('initial'), isFalse);
    expect(activity.state.unreadCount, 2);
    repository.rejectReadUpdates = false;
    expect(await activity.markRead('initial'), isTrue);
    expect(activity.state.unreadCount, 1);
    expect(await activity.markAllRead(), isTrue);
    expect(activity.state.unreadCount, 0);
    expect(await activity.dismiss('initial'), isTrue);
    expect(activity.state.items.single.id, 'second');
  });
}
