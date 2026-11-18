import 'package:flutter/material.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';

import '../../domain/entities/feed_item.dart';

class FeedItemCard extends StatelessWidget {
  final FeedItem feedItem;
  final void Function(String postId) onPostTap;
  final void Function(String postId, bool isLiked, int likesCount) onLikeToggle;

  const FeedItemCard({
    super.key,
    required this.feedItem,
    required this.onPostTap,
    required this.onLikeToggle,
  });

  @override
  Widget build(BuildContext context) => PostCard(
        key: ValueKey(feedItem.id),
        post: feedItem.toPost(),
        onPostTap: onPostTap,
        onLikeToggle: onLikeToggle,
      );
}
