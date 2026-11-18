import 'dart:async';

import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:instagram_clone/features/notifications/data/models/notification_model.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final SupabaseClient supabaseClient;

  NotificationRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await supabaseClient
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw ServerException(message: 'Failed to delete notification: $e');
    }
  }

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await supabaseClient
          .from('notifications')
          .select(
              'id,user_id,actor_id,type,resource_id,message,is_read,created_at,'
              'actor:users!notifications_actor_id_fkey(${SupabaseConstants.publicUserColumns})')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('id', ascending: false);

      return (response as List)
          .map((notification) => NotificationModel.fromJson(notification))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get notifications: $e');
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(
          message: 'Failed to mark all notifications as read: $e');
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(message: 'Failed to mark notification as read: $e');
    }
  }

  @override
  Stream<void> watchChanges(String userId) {
    final controller = StreamController<void>();
    final channel = supabaseClient.channel('veyro-activity:$userId');
    final recipient = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq, column: 'user_id', value: userId);
    var active = true;
    void changed() {
      if (active) controller.add(null);
    }

    controller.onListen = () {
      // Inserts and mark-read updates are filtered to the recipient. Deletes
      // on another device are picked up by the normal foreground refresh.
      for (final event in [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update
      ]) {
        channel.onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'notifications',
            filter: recipient,
            callback: (_) => changed());
      }
      channel.subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) changed();
      });
    };
    controller.onCancel = () async {
      active = false;
      await supabaseClient.removeChannel(channel);
    };
    return controller.stream;
  }
}
