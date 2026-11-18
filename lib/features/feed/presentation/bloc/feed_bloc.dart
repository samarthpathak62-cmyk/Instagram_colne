import 'package:instagram_clone/features/post/domain/usecases/like_post.dart';
import 'package:instagram_clone/features/post/domain/usecases/unlike_post.dart';
// lib/features/feed/presentation/bloc/feed_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart'; // Assuming Failure definitions are here
import '../../domain/usecases/get_feed.dart'; // Assuming GetFeed use case is defined
import '../../domain/usecases/refresh_feed.dart'; // Assuming RefreshFeed use case is defined
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/feed_item.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeed _getFeed;
  final RefreshFeed _refreshFeed;
  final LikePost _likePost;
  final UnlikePost _unlikePost;
  final _pendingLikes = <String>{};
  bool _fetching = false;

  FeedBloc({
    required GetFeed getFeed,
    required RefreshFeed refreshFeed,
    required LikePost likePost,
    required UnlikePost unlikePost,
  })  : _getFeed = getFeed,
        _refreshFeed = refreshFeed,
        _likePost = likePost,
        _unlikePost = unlikePost,
        super(FeedInitial()) {
    on<LoadFeed>(_onLoadFeed);
    on<RefreshFeedEvent>(_onRefreshFeed);
    on<UpdateFeedPostLikeStatus>(_onUpdateFeedPostLikeStatus);
  }

  Future<void> _onLoadFeed(LoadFeed event, Emitter<FeedState> emit) async {
    if (_fetching ||
        (state is FeedLoaded && (state as FeedLoaded).hasReachedMax)) return;
    _fetching = true;

    final currentState = state;
    List<FeedItem> oldFeedItems = [];
    if (currentState is FeedLoaded) {
      oldFeedItems = currentState.feedItems;
    }

    if (oldFeedItems.isEmpty) emit(FeedLoading());

    final result =
        await _getFeed(GetFeedParams(page: event.page, limit: event.limit));
    _fetching = false;

    result.fold(
      (failure) => emit(FeedError(message: _mapFailureToMessage(failure))),
      (newFeedItems) {
        final allFeedItems = oldFeedItems + newFeedItems;
        emit(FeedLoaded(
          feedItems: allFeedItems,
          hasReachedMax: newFeedItems.length < event.limit,
        ));
      },
    );
  }

  Future<void> _onRefreshFeed(
      RefreshFeedEvent event, Emitter<FeedState> emit) async {
    emit(FeedLoading()); // Emit loading state for refresh

    final result = await _refreshFeed(NoParams());

    result.fold(
      (failure) => emit(FeedError(message: _mapFailureToMessage(failure))),
      (feedItems) => emit(FeedLoaded(
          feedItems: feedItems, hasReachedMax: feedItems.length < 10)),
    );
  }

  Future<void> _onUpdateFeedPostLikeStatus(
      UpdateFeedPostLikeStatus event, Emitter<FeedState> emit) async {
    if (state is! FeedLoaded || !_pendingLikes.add(event.postId)) return;
    final result = event.isLiked
        ? await _likePost(
            LikePostParams(postId: event.postId, userId: event.userId))
        : await _unlikePost(
            UnlikePostParams(postId: event.postId, userId: event.userId));
    _pendingLikes.remove(event.postId);
    final current = state;
    if (current is! FeedLoaded) return;
    result.fold(
      (failure) => emit(FeedError(message: failure.message)),
      (_) => emit(current.copyWith(
          feedItems: current.feedItems.map((item) {
        return item.id == event.postId
            ? item.copyWith(
                isLiked: event.isLiked,
                likesCount: event.likesCount,
              )
            : item;
      }).toList())),
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return (failure as ServerFailure).message;
      case CacheFailure:
        return (failure as CacheFailure).message;
      case NetworkFailure:
        return (failure as NetworkFailure).message;
      case SupabaseFailure:
        return (failure as SupabaseFailure).message;
      default:
        return 'Unexpected error occurred';
    }
  }
}
