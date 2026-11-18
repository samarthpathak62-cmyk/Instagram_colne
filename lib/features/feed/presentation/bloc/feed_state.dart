import 'package:instagram_clone/features/feed/domain/entities/feed_item.dart';

enum FeedTimeline { latest, following }

class FeedState {
  final FeedTimeline timeline;
  final List<FeedItem> items;
  final bool loading;
  final bool hasMore;
  final bool refreshing;
  final String? error;

  const FeedState({
    this.timeline = FeedTimeline.latest,
    this.items = const [],
    this.loading = true,
    this.hasMore = true,
    this.refreshing = false,
    this.error,
  });
}
