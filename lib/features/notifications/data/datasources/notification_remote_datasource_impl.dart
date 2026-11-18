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
          .order('created_at', ascending: false);

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
          .update({'is_read': true}).eq('user_id', userId);
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
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      throw ServerException(message: 'Failed to mark notification as read: $e');
    }
  }

  @override
  Future<Stream<NotificationModel>> subscribeToNotifications(
      String userId) async {
    try {
      return supabaseClient
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .where((rows) => rows.isNotEmpty)
          .map((rows) => NotificationModel.fromJson(rows.first));
    } catch (e) {
      throw ServerException(
          message: 'Failed to subscribe to notifications: $e');
    }
  }
}
