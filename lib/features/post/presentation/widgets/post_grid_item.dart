import 'package:flutter/material.dart';
import '../../domain/entities/post.dart';

class PostGridItem extends StatelessWidget {
  final Post post;

  const PostGridItem({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to post detail screen
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => PostDetailScreen(postId: post.id),
        //   ),
        // );
      },
      child: Container(
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Post media
            _buildMediaWidget(context),

            // Overlay for video indicator
            if (post.mediaType == 'video')
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Overlay for multiple media indicator
            if (post.mediaUrls.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.collections,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaWidget(BuildContext context) {
    if (post.mediaUrls.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final mediaUrl = post.mediaUrls.first;

    if (post.mediaType == 'video') {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    } else {
      return Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    }
  }
}
