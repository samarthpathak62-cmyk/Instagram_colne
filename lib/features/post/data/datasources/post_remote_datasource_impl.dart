import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/media/supabase_media_upload.dart';
import 'package:instagram_clone/features/post/data/datasources/post_remote_datasource.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  final SupabaseClient supabaseClient;

  PostRemoteDataSourceImpl({required this.supabaseClient});

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _postsForViewer() {
    final posts = supabaseClient.from(SupabaseConstants.postsTable);
    final viewerId = supabaseClient.auth.currentUser?.id;
    if (viewerId == null) return posts.select(PostModel.columns);
    // Filter only the embedded likes, not the posts themselves. An unliked
    // post must still appear in the feed and remain openable.
    return posts
        .select(PostModel.columnsWithViewer)
        .eq('liked_by_user.user_id', viewerId);
  }

  @override
  Future<PostModel> createPost({
    required String authorId,
    required PostType type,
    required List<XFile> mediaFiles,
    String? description,
  }) async {
    try {
      if (mediaFiles.isEmpty) {
        throw ServerException(message: 'Choose a photo or video first.');
      }
      final mediaUrls = <String>[];
      for (final file in mediaFiles) {
        mediaUrls.add(await uploadPublicMedia(
          client: supabaseClient,
          file: file,
          bucket: SupabaseConstants.postMediaBucket,
          ownerId: authorId,
          isVideo: type == PostType.video,
        ));
      }
      final post = await supabaseClient
          .from(SupabaseConstants.postsTable)
          .insert({
            'author_id': authorId,
            'type': type.name,
            'media_urls': mediaUrls,
            'description': description,
          })
          .select(PostModel.columns)
          .single();
      return PostModel.fromJson(post);
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not create post: ${error.message}');
    } on StorageException catch (error) {
      throw ServerException(
          message: 'Could not upload media: ${error.message}');
    } on FileUploadException catch (error) {
      throw ServerException(message: error.message);
    }
  }

  @override
  Future<PostModel> getPost(String postId) async {
    try {
      final post = await _postsForViewer().eq('id', postId).single();
      return PostModel.fromJson(post);
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not load post: ${error.message}');
    }
  }

  @override
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final posts = await _postsForViewer()
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      return posts.map(PostModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not load profile posts: ${error.message}');
    }
  }

  @override
  Future<List<PostModel>> getFeedPosts(String currentUserId) async {
    try {
      final follows = await supabaseClient
          .from(SupabaseConstants.followersTable)
          .select('following_id')
          .eq('follower_id', currentUserId);
      final authors = [
        currentUserId,
        ...follows.map((row) => row['following_id'] as String)
      ];
      final posts = await _postsForViewer()
          .inFilter('author_id', authors)
          .order('created_at', ascending: false);
      return posts.map(PostModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not load feed: ${error.message}');
    }
  }

  @override
  Future<void> likePost(String postId, String userId) async {
    try {
      await supabaseClient
          .from('likes')
          .insert({'post_id': postId, 'user_id': userId});
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        throw ServerException(message: 'Could not like post: ${error.message}');
      }
    }
  }

  @override
  Future<void> unlikePost(String postId, String userId) async {
    try {
      await supabaseClient
          .from('likes')
          .delete()
          .match({'post_id': postId, 'user_id': userId});
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not unlike post: ${error.message}');
    }
  }

  @override
  Future<List<PostModel>> getVideoExplorePosts(
      {int limit = 10, int offset = 0}) async {
    try {
      final posts = await _postsForViewer()
          .eq('type', 'video')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return posts.map(PostModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not load videos: ${error.message}');
    }
  }
}
