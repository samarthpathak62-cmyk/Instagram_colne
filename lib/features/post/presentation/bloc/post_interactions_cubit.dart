import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/domain/repositories/post_repository.dart';

class PostInteraction extends Equatable {
  final bool? liked;
  final bool? saved;
  final int? commentCount;
  final String? description;
  final bool liking;
  final bool saving;
  final bool editing;
  final bool deleted;

  const PostInteraction({
    this.liked,
    this.saved,
    this.commentCount,
    this.description,
    this.liking = false,
    this.saving = false,
    this.editing = false,
    this.deleted = false,
  });

  bool isLiked(Post post) => liked ?? post.isLikedByCurrentUser;
  bool isSaved(Post post) => saved ?? post.isSavedByCurrentUser;
  int likes(Post post) => math.max(
      0,
      post.likeCount +
          (isLiked(post) ? 1 : 0) -
          (post.isLikedByCurrentUser ? 1 : 0));
  int comments(Post post) => commentCount ?? post.commentCount;
  String text(Post post) =>
      description ?? post.description ?? post.caption ?? '';

  PostInteraction copyWith(
          {bool? liked,
          bool? saved,
          int? commentCount,
          String? description,
          bool? liking,
          bool? saving,
          bool? editing,
          bool? deleted}) =>
      PostInteraction(
        liked: liked ?? this.liked,
        saved: saved ?? this.saved,
        commentCount: commentCount ?? this.commentCount,
        description: description ?? this.description,
        liking: liking ?? this.liking,
        saving: saving ?? this.saving,
        editing: editing ?? this.editing,
        deleted: deleted ?? this.deleted,
      );

  @override
  List<Object?> get props => [
        liked,
        saved,
        commentCount,
        description,
        liking,
        saving,
        editing,
        deleted
      ];
}

/// A session-scoped overlay: the feed, reels and post detail reflect the same
/// changes without duplicating writes or losing the list on a failed action.
class PostInteractionsCubit extends Cubit<Map<String, PostInteraction>> {
  final PostRepository repository;
  final String userId;

  PostInteractionsCubit({required this.repository, required this.userId})
      : super(const {});

  PostInteraction forPost(String id) => state[id] ?? const PostInteraction();

  void _patch(String id, PostInteraction Function(PostInteraction) change) {
    if (!isClosed) emit(Map.unmodifiable({...state, id: change(forPost(id))}));
  }

  Future<String?> toggleLike(Post post, {bool likeOnly = false}) async {
    final current = forPost(post.id);
    final wasLiked = current.isLiked(post);
    if (current.liking || current.deleted || (likeOnly && wasLiked))
      return null;
    _patch(post.id, (value) => value.copyWith(liked: !wasLiked, liking: true));
    final result = await (wasLiked
        ? repository.unlikePost(post.id, userId)
        : repository.likePost(post.id, userId));
    return result.fold((failure) {
      _patch(
          post.id, (value) => value.copyWith(liked: wasLiked, liking: false));
      return failure.message;
    }, (_) {
      _patch(post.id, (value) => value.copyWith(liking: false));
      return null;
    });
  }

  Future<String?> toggleSave(Post post) =>
      setSaved(post, !forPost(post.id).isSaved(post));

  Future<String?> setSaved(Post post, bool saved) async {
    final current = forPost(post.id);
    final wasSaved = current.isSaved(post);
    if (current.saving || current.deleted || saved == wasSaved) return null;
    _patch(post.id, (value) => value.copyWith(saved: saved, saving: true));
    final result = await repository.setSaved(post.id, userId, saved);
    return result.fold((failure) {
      _patch(
          post.id, (value) => value.copyWith(saved: wasSaved, saving: false));
      return failure.message;
    }, (_) {
      _patch(post.id, (value) => value.copyWith(saving: false));
      return null;
    });
  }

  void updateCommentCount(String postId, int total) {
    if (forPost(postId).commentCount != total) {
      _patch(postId, (value) => value.copyWith(commentCount: total));
    }
  }

  Future<String?> edit(Post post, String description) async {
    if (post.authorId != userId) return 'Only the author can edit this post.';
    final current = forPost(post.id);
    final text = description.trim();
    if (post.type == PostType.text && text.isEmpty)
      return 'Write something before saving.';
    if (current.editing || current.deleted) return null;
    _patch(post.id, (value) => value.copyWith(editing: true));
    final result = await repository.editPost(post.id, userId, text);
    final error =
        result.fold<String?>((failure) => failure.message, (_) => null);
    _patch(
        post.id,
        (value) => value.copyWith(
            editing: false, description: error == null ? text : null));
    return error;
  }

  Future<String?> delete(Post post) async {
    if (post.authorId != userId) return 'Only the author can delete this post.';
    final current = forPost(post.id);
    if (current.editing || current.deleted) return null;
    _patch(post.id, (value) => value.copyWith(editing: true));
    final result = await repository.deletePost(post.id, userId);
    final error =
        result.fold<String?>((failure) => failure.message, (_) => null);
    _patch(post.id,
        (value) => value.copyWith(editing: false, deleted: error == null));
    return error;
  }
}
