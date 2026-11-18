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
          .select(
              'id,user_id,post_id,created_at,post:posts(${PostModel.columnsWithViewer})')
          .eq('post.liked_by_user.user_id', userId)
          .eq('post.saved_by_user.user_id', userId)
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map(FavoriteModel.fromJson).toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get favorites: $e');
    }
  }
}
