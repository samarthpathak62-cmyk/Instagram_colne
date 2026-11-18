import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';

import '../../domain/entities/feed_item.dart';

class FeedItemModel extends FeedItem {
  const FeedItemModel({
    required super.id,
    required super.userId,
    required super.mediaUrl,
    required super.mediaType,
    super.caption,
    required super.createdAt,
    required super.likesCount,
    required super.commentsCount,
    required super.user,
    required super.isLiked,
    required super.isSaved,
    required super.mediaUrls,
  });

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    final post = PostModel.fromJson(json);
    return FeedItemModel(
      id: post.id,
      userId: post.authorId,
      mediaUrl: post.mediaUrl ?? '',
      mediaType: post.type.name,
      caption: post.description ?? post.caption,
      createdAt: post.createdAt,
      likesCount: post.likeCount,
      isLiked: post.isLikedByCurrentUser,
      isSaved: post.isSavedByCurrentUser,
      mediaUrls: post.mediaUrls,
      commentsCount: post.commentCount,
      user: post.author ?? UserModel(id: post.authorId, email: ''),
    );
  }
}
