import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:instagram_clone/features/favorites/data/datasources/favorite_remote_datasource.dart';
import 'package:instagram_clone/features/favorites/data/models/favorite_model.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteRemoteDataSourceImpl implements FavoriteRemoteDataSource {
  final SupabaseClient supabaseClient;

  FavoriteRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<FavoriteModel>> getFavorites(String userId) async {
    try {
      final response = await supabaseClient
          .from(SupabaseConstants.savedPostsTable)
          .select('*, post:posts(${PostModel.columns})')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map(FavoriteModel.fromJson).toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get favorites: $e');
    }
  }

  @override
  Future<String?> getSavedPostId(String userId, String postId) async {
    try {
      final response = await supabaseClient
          .from(SupabaseConstants.savedPostsTable)
          .select('id')
          .eq('user_id', userId)
          .eq('post_id', postId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      throw ServerException(message: 'Failed to check if post is saved: $e');
    }
  }

  @override
  Future<FavoriteModel> savePost(String userId, String postId) async {
    try {
      final favoriteData = {
        'user_id': userId,
        'post_id': postId,
      };

      final response = await supabaseClient
          .from(SupabaseConstants.savedPostsTable)
          .upsert(favoriteData, onConflict: 'user_id,post_id')
          .select('*, post:posts(${PostModel.columns})')
          .single();

      return FavoriteModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: 'Failed to save post: $e');
    }
  }

  @override
  Future<void> unsavePost(String favoriteId) async {
    try {
      await supabaseClient
          .from(SupabaseConstants.savedPostsTable)
          .delete()
          .eq('id', favoriteId);
    } catch (e) {
      throw ServerException(message: 'Failed to unsave post: $e');
    }
  }
}
