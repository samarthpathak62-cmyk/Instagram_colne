import 'package:instagram_clone/features/post/domain/entities/post_reaction.dart';
import 'package:instagram_clone/features/post/domain/entities/post_comment.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:dartz/dartz.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';

abstract class PostRepository {
  Future<Either<Failure, Post>> createPost({
    required String authorId,
    required PostType type,
    required List<XFile> mediaFiles, // List of image files or single video file
    String? description,
    String? groupId,
  });

  Future<Either<Failure, Post?>> findRepost(String postId, String userId);
  Future<Either<Failure, Post>> createShare(String postId, String userId,
      {String? quote});

  Future<Either<Failure, Post>> getPost(String postId);

  Future<Either<Failure, List<Post>>> getUserPosts(String userId);

  Future<Either<Failure, List<Post>>> getVideoExplorePosts(
      {int limit = 10, int offset = 0}); // For video explore screen

  Future<Either<Failure, void>> likePost(String postId, String userId);

  Future<Either<Failure, void>> unlikePost(String postId, String userId);
  Future<Either<Failure, void>> setReaction(
      String postId, PostReaction reaction);

  Future<Either<Failure, CommentPage>> getComments(String postId,
      {int offset = 0});
  Future<Either<Failure, PostComment>> addComment(
      String postId, String userId, String content);
  Future<Either<Failure, void>> setSaved(
      String postId, String userId, bool saved);
  Future<Either<Failure, void>> deleteComment(String commentId, String userId);
  Future<Either<Failure, void>> editPost(
      String postId, String userId, String description);
  Future<Either<Failure, void>> deletePost(String postId, String userId);
}
