import 'package:instagram_clone/features/post/domain/entities/post_reaction.dart';
// lib/features/feed/domain/entities/feed_item.dart

import 'package:equatable/equatable.dart'; // For value equality
import '../../../auth/domain/entities/user.dart'; // Assuming User entity is defined
import '../../../post/domain/entities/post.dart'; // For Post conversion

/// Represents a single item in the user's feed.
/// This is a core entity in the Domain Layer.
class FeedItem extends Equatable {
  final String id;
  final String userId;
  final String mediaUrl;
  final String mediaType; // e.g., 'image', 'video'
  final String? caption;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final List<String> mediaUrls;
  final User user; // The user who posted this item
  final PostReaction? viewerReaction;
  final Map<PostReaction, int> reactionCounts;
  final String? groupId;
  final String? groupName;
  final PostShareKind? shareKind;
  final String? sharedPostId;
  final Post? sharedPost;

  const FeedItem({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.user,
    this.isLiked = false,
    this.isSaved = false,
    this.mediaUrls = const [],
    this.viewerReaction,
    this.reactionCounts = const {},
    this.groupId,
    this.groupName,
    this.shareKind,
    this.sharedPostId,
    this.sharedPost,
  });

  // Copy with method for immutable updates
  FeedItem copyWith({
    String? id,
    String? userId,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    User? user,
  }) {
    return FeedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      user: user ?? this.user,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved,
      mediaUrls: mediaUrls,
      viewerReaction: viewerReaction,
      reactionCounts: reactionCounts,
      groupId: groupId,
      groupName: groupName,
      shareKind: shareKind,
      sharedPostId: sharedPostId,
      sharedPost: sharedPost,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        mediaUrl,
        mediaType,
        caption,
        createdAt,
        likesCount,
        commentsCount,
        user,
        isLiked,
        isSaved,
        mediaUrls,
        viewerReaction,
        reactionCounts,
        groupId,
        groupName,
        shareKind,
        sharedPostId,
        sharedPost,
      ];

  @override
  bool get stringify => true; // For better debugging output

  // Convert FeedItem to Post for compatibility with PostActions widget
  Post toPost() {
    return Post(
      id: id,
      authorId: userId,
      user: user,
      type: PostType.values.firstWhere((type) => type.name == mediaType,
          orElse: () => PostType.image),
      mediaUrls: mediaUrls,
      viewerReaction: viewerReaction,
      reactionCounts: reactionCounts,
      groupId: groupId,
      groupName: groupName,
      shareKind: shareKind,
      sharedPostId: sharedPostId,
      sharedPost: sharedPost,
      description: caption,
      caption: caption,
      createdAt: createdAt,
      likeCount: likesCount,
      commentCount: commentsCount,
      likesCount: likesCount,
      commentsCount: commentsCount,
      isLikedByCurrentUser: isLiked,
      isSavedByCurrentUser: isSaved,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }
}
