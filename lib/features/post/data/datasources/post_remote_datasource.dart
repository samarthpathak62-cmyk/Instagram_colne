import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/features/post/data/models/post_model.dart'; // To be created
import 'package:instagram_clone/features/post/domain/entities/post.dart'; // For PostType

abstract class PostRemoteDataSource {
  Future<PostModel> createPost({
    required String authorId,
    required PostType type,
    required List<XFile> mediaFiles,
    String? description,
  });

  Future<PostModel> getPost(String postId);

  Future<List<PostModel>> getUserPosts(String userId);

  Future<List<PostModel>> getFeedPosts(String currentUserId);

  Future<List<PostModel>> getVideoExplorePosts(
      {int limit = 10, int offset = 0}); // Added for video explore

  Future<void> likePost(String postId, String userId);

  Future<void> unlikePost(String postId, String userId);
}
