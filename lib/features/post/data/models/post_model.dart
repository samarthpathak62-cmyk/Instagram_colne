import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';

class PostModel extends Post {
  // Shared PostgREST projection for the feed, explore, favorites and detail views.
  static const _previewColumns =
      'id,author_id,type,media_urls,description,caption,created_at,share_kind,'
      'author:users!posts_author_id_fkey(${SupabaseConstants.publicUserColumns})';
  static const columns =
      '$_previewColumns,shared_post_id,source:veyro_shared_post($_previewColumns),'
      'likes(count),comments(count)';
  static const columnsWithViewer =
      '$columns,liked_by_user:likes(user_id),saved_by_user:saved_posts(id)';

  const PostModel({
    required super.id,
    required super.authorId,
    super.user,
    required super.type,
    required super.mediaUrls,
    super.description,
    super.caption,
    required super.createdAt,
    super.likeCount,
    super.commentCount,
    super.likesCount,
    super.commentsCount,
    super.isLikedByCurrentUser,
    super.isSavedByCurrentUser,
    super.mediaUrl,
    super.mediaType,
    super.shareKind,
    super.sharedPostId,
    super.sharedPost,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int counts, defaulting to 0
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Handle nested counts and author data
    final likeData = json['likes'] as List?;
    final commentData = json['comments'] as List?;
    final authorData = json['author'] as Map<String, dynamic>?;
    final source = json['source'] as Map<String, dynamic>?;
    final likedByUserList = json['liked_by_user'] as List?;

    final likeCount = (likeData != null && likeData.isNotEmpty)
        ? parseInt(likeData.first?['count'])
        : 0;
    final commentCount = (commentData != null && commentData.isNotEmpty)
        ? parseInt(commentData.first?['count'])
        : 0;
    final isLiked = likedByUserList?.isNotEmpty ?? false;
    final user = authorData == null ? null : UserModel.fromJson(authorData);

    // Parse media URLs
    List<String> mediaUrls = [];
    if (json['media_urls'] is List) {
      mediaUrls = (json['media_urls'] as List).whereType<String>().toList();
    } else if (json['media_urls'] is String) {
      mediaUrls = [json['media_urls'] as String];
    }

    return PostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      user: user,
      type: PostType.values.firstWhere((e) => e.name == json['type'],
          orElse: () => PostType.image),
      mediaUrls: mediaUrls,
      description: json['description'] as String?,
      caption: json['caption'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      likeCount: likeCount,
      commentCount: commentCount,
      likesCount: likeCount,
      commentsCount: commentCount,
      isLikedByCurrentUser: isLiked,
      isSavedByCurrentUser:
          (json['saved_by_user'] as List?)?.isNotEmpty ?? false,
      mediaUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      mediaType: json['type'] as String?,
      shareKind: switch (json['share_kind']) {
        'repost' => PostShareKind.repost,
        'quote' => PostShareKind.quote,
        _ => null,
      },
      sharedPostId: json['shared_post_id'] as String?,
      sharedPost: source == null ? null : PostModel.fromJson(source),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'type': type.name,
      'media_urls': mediaUrls,
      'description': description,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
