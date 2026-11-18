import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/feed/domain/entities/feed_item.dart';
import 'package:instagram_clone/features/feed/domain/usecases/get_feed.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_state.dart';

class FeedCubit extends Cubit<FeedState> {
  static const pageSize = 10;
  final GetFeed _getFeed;
  int _generation = 0;
  int _page = 0;

  FeedCubit(this._getFeed) : super(const FeedState());

  Future<void> selectTimeline(FeedTimeline timeline) async {
    if (timeline != state.timeline) await refresh(timeline: timeline);
  }

  Future<void> refresh({FeedTimeline? timeline}) =>
      _load(reset: true, timeline: timeline ?? state.timeline);

  Future<void> loadMore({bool retry = false}) async {
    if (state.loading || !state.hasMore || (!retry && state.error != null))
      return;
    await _load(reset: false, timeline: state.timeline);
  }

  Future<void> _load(
      {required bool reset, required FeedTimeline timeline}) async {
    final request = ++_generation;
    final sameTimeline = timeline == state.timeline;
    final existing = sameTimeline ? state.items : const <FeedItem>[];
    final page = reset ? 0 : _page;
    emit(FeedState(
        timeline: timeline,
        items: existing,
        refreshing: reset && sameTimeline));
    final result = await _getFeed(GetFeedParams(
      page: page,
      limit: pageSize,
      following: timeline == FeedTimeline.following,
    ));
    if (isClosed || request != _generation) return;
    result.fold(
      (failure) => emit(FeedState(
          timeline: timeline,
          items: existing,
          loading: false,
          error: failure.message)),
      (items) {
        _page = page + 1;
        final base = reset ? const <FeedItem>[] : existing;
        final previousIds = base.map((item) => item.id).toSet();
        emit(FeedState(
          timeline: timeline,
          items: [...base, ...items.where((item) => previousIds.add(item.id))],
          loading: false,
          hasMore: items.length == pageSize,
        ));
      },
    );
  }
}
