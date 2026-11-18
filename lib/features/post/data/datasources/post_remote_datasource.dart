import 'package:instagram_clone/features/post/domain/entities/post_reaction.dart';
import 'package:instagram_clone/features/post/domain/entities/post_comment.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/features/post/data/models/post_model.dart'; // To be created
import 'package:instagram_clone/features/post/domain/entities/post.dart'; // For PostType

abstract class PostRemoteDataSource {
  Future<PostModel> createPost({
    required String authorId,
    required PostType type,
    required List<XFile> mediaFiles,
    String? description,
    String? groupId,
  });

  Future<PostModel?> findRepost(String postId, String userId);
  Future<PostModel> createShare(String postId, String userId, {String? quote});

  Future<PostModel> getPost(String postId);

  Future<List<PostModel>> getUserPosts(String userId);

  Future<List<PostModel>> getVideoExplorePosts(
      {int limit = 10, int offset = 0}); // Added for video explore

  Future<void> likePost(String postId, String userId);

  Future<void> unlikePost(String postId, String userId);
  Future<void> setReaction(String postId, PostReaction reaction);

  Future<CommentPage> getComments(String postId, {int offset = 0});
  Future<PostComment> addComment(String postId, String userId, String content);
  Future<void> setSaved(String postId, String userId, bool saved);
  Future<void> deleteComment(String commentId, String userId);
  Future<void> editPost(String postId, String userId, String description);
  Future<void> deletePost(String postId, String userId);
}
