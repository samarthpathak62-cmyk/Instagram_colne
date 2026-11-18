// lib/features/post/presentation/widgets/post_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart'; // Assuming UserAvatar is defined
import 'package:instagram_clone/features/post/domain/entities/post.dart'; // Assuming Post entity is defined
import 'package:instagram_clone/features/post/presentation/widgets/post_actions.dart'; // Assuming PostActions is defined
import 'package:instagram_clone/features/post/presentation/widgets/video_player_widget.dart'; // Assuming VideoPlayerWidget is defined
import 'package:timeago/timeago.dart' as timeago; // For formatting time

class PostCard extends StatelessWidget {
  final Post post;
  final Function(String postId)? onPostTap;
  final Function(String postId, bool isLiked, int likesCount)? onLikeToggle;
  // Add more callbacks for comments, share, save if needed

  const PostCard({
    Key? key,
    required this.post,
    this.onPostTap,
    this.onLikeToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final username = post.user?.username ?? 'User';
    final caption = post.description ?? post.caption;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Info and Options
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: post.user?.profilePictureUrl,
                  radius: 18,
                  onTap: () {
                    // Navigate to user profile
                    // Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen.withProviders(post.user.id)));
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    username,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Show post options (report, unfollow, etc.)
                  },
                ),
              ],
            ),
          ),

          // Media Content (Image or Video)
          GestureDetector(
            onDoubleTap: () {
              if (!post.isLikedByCurrentUser) {
                onLikeToggle?.call(post.id, true, post.likesCount + 1);
              }
            },
            onTap: onPostTap != null ? () => onPostTap!(post.id) : null,
            child: AspectRatio(
              aspectRatio: 1.0, // Square aspect ratio for posts
              child: post.mediaUrl?.isNotEmpty != true
                  ? const Center(
                      child: Icon(Icons.image_not_supported_outlined))
                  : post.type == PostType.video
                      ? VideoPlayerWidget(videoUrl: post.mediaUrl!)
                      : Image.network(
                          post.mediaUrl ?? '',
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                  child: Icon(Icons.broken_image, size: 50)),
                        ),
            ),
          ),

          // Actions (Like, Comment, Share, Save)
          if (auth is Authenticated)
            PostActions(
              postId: post.id,
              userId: auth.user.id,
              post: post,
              isLiked: post.isLikedByCurrentUser,
              likesCount: post.likesCount,
              onLikeToggle: onLikeToggle,
              onComment: () {
                // Navigate to comments screen
              },
              onShare: () {
                // Implement share functionality
              },
            ),

          // Likes Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              '${post.likesCount} likes',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),

          // Caption
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: '$username ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: caption),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),

          // View all comments (placeholder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: GestureDetector(
              onTap: () {
                // Navigate to comments screen
              },
              child: Text(
                'View all ${post.commentsCount} comments',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Time Ago
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              timeago.format(post.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
