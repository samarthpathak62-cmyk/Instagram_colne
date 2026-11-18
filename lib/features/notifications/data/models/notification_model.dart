import 'package:instagram_clone/features/notifications/domain/entities/notification.dart';

class NotificationModel extends Notification {
  const NotificationModel({
    required super.id,
    required super.userId,
    super.actorId,
    required super.type,
    super.resourceId,
    required super.message,
    super.isRead = false,
    required super.createdAt,
    super.senderUsername,
    super.senderProfilePictureUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      actorId: json['actor_id'],
      senderUsername: actor?['username'] as String?,
      senderProfilePictureUrl: actor?['profile_picture_url'] as String?,
      type: _mapStringToNotificationType(json['type']),
      resourceId: json['resource_id'],
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'actor_id': actorId,
      'type': type.toString().split('.').last,
      'resource_id': resourceId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static NotificationType _mapStringToNotificationType(String type) {
    switch (type) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'mention':
        return NotificationType.mention;
      case 'taggedInPost':
        return NotificationType.taggedInPost;
      case 'taggedInComment':
        return NotificationType.taggedInComment;
      case 'newFollowerPost':
        return NotificationType.newFollowerPost;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }
}
