import 'package:instagram_clone/features/post/data/models/post_comment_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post_comment.dart';
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
        .eq('liked_by_user.user_id', viewerId)
        .eq('saved_by_user.user_id', viewerId);
  }

  @override
  Future<PostModel> createPost({
    required String authorId,
    required PostType type,
    required List<XFile> mediaFiles,
    String? description,
  }) async {
    try {
      final text = description?.trim() ?? '';
      if (text.runes.length > Post.maxDescriptionLength) {
        throw ServerException(
            message: 'Write up to ${Post.maxDescriptionLength} characters.');
      }
      if (type == PostType.text) {
        if (text.isEmpty || mediaFiles.isNotEmpty) {
          throw ServerException(message: 'Add text for your update.');
        }
      } else if (mediaFiles.isEmpty ||
          (type == PostType.video && mediaFiles.length != 1) ||
          mediaFiles.length > 8) {
        throw ServerException(message: 'Choose up to 8 photos or one video.');
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
            'description': text.isEmpty ? null : text,
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
  Future<PostModel?> findRepost(String postId, String userId) async {
    try {
      final row = await _postsForViewer()
          .eq('share_kind', 'repost')
          .eq('shared_post_id', postId)
          .eq('author_id', userId)
          .maybeSingle();
      return row == null ? null : PostModel.fromJson(row);
    } on PostgrestException {
      throw ServerException(message: 'Could not check this repost. Try again.');
    }
  }

  @override
  Future<PostModel> createShare(String postId, String userId,
      {String? quote}) async {
    final text = quote?.trim();
    if (text != null &&
        (text.isEmpty || text.runes.length > Post.maxDescriptionLength)) {
      throw ServerException(message: 'Write 1–500 characters to quote a post.');
    }
    try {
      final row = await supabaseClient
          .from(SupabaseConstants.postsTable)
          .insert({
            'author_id': userId,
            'type': PostType.text.name,
            'description': text ?? 'Reposted a post on Veyro.',
            'media_urls': <String>[],
            'shared_post_id': postId,
            'share_kind': text == null ? 'repost' : 'quote',
          })
          .select(PostModel.columns)
          .single();
      return PostModel.fromJson(row);
    } on PostgrestException catch (error) {
      // Another device could have reposted while this menu was open.
      if (text == null && error.code == '23505') {
        final existing = await findRepost(postId, userId);
        if (existing != null) return existing;
      }
      throw ServerException(
          message: error.code == '23503'
              ? 'The original post is no longer available.'
              : 'Could not share this post. Try again.');
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
          .order('created_at', ascending: false, nullsFirst: false)
          .order('id', ascending: false);
      return posts.map(PostModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not load profile posts: ${error.message}');
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
          .order('created_at', ascending: false, nullsFirst: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);
      return posts.map(PostModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw ServerException(message: 'Could not load videos: ${error.message}');
    }
  }

  @override
  Future<CommentPage> getComments(String postId, {int offset = 0}) async {
    final response = await supabaseClient
        .from('comments')
        .select(PostCommentModel.columns)
        .eq('post_id', postId)
        .order('created_at', ascending: false, nullsFirst: false)
        .order('id', ascending: false)
        .range(offset, offset + CommentPage.size - 1)
        .count(CountOption.exact);
    return CommentPage(
        response.data.map(PostCommentModel.fromJson).toList(), response.count);
  }

  @override
  Future<PostComment> addComment(
      String postId, String userId, String content) async {
    final value = content.trim();
    if (value.isEmpty || value.runes.length > CommentPage.maxLength) {
      throw ServerException(
          message:
              'Write a comment up to ${CommentPage.maxLength} characters.');
    }
    final row = await supabaseClient
        .from('comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'content': value,
        })
        .select(PostCommentModel.columns)
        .single();
    return PostCommentModel.fromJson(row);
  }

  @override
  Future<void> deleteComment(String commentId, String userId) async {
    final deleted = await supabaseClient
        .from('comments')
        .delete()
        .match({'id': commentId, 'user_id': userId}).select('id');
    if (deleted.isEmpty)
      throw ServerException(message: 'Could not remove this comment.');
  }

  @override
  Future<void> setSaved(String postId, String userId, bool saved) async {
    final posts = supabaseClient.from(SupabaseConstants.savedPostsTable);
    final match = {'post_id': postId, 'user_id': userId};
    if (saved) {
      await posts.upsert(match,
          onConflict: 'user_id,post_id', ignoreDuplicates: true);
    } else {
      await posts.delete().match(match);
    }
  }

  @override
  Future<void> editPost(
      String postId, String userId, String description) async {
    final text = description.trim();
    if (text.runes.length > Post.maxDescriptionLength) {
      throw ServerException(
          message: 'Write up to ${Post.maxDescriptionLength} characters.');
    }
    final updated = await supabaseClient
        .from(SupabaseConstants.postsTable)
        .update({'description': text, 'caption': null}).match(
            {'id': postId, 'author_id': userId}).select('id');
    if (updated.isEmpty)
      throw ServerException(message: 'Could not update this post.');
  }

  @override
  Future<void> deletePost(String postId, String userId) async {
    final deleted = await supabaseClient
        .from(SupabaseConstants.postsTable)
        .delete()
        .match({'id': postId, 'author_id': userId}).select('id');
    if (deleted.isEmpty)
      throw ServerException(message: 'Could not delete this post.');
  }
}
