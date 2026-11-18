import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart'
    as app_user;
import 'package:instagram_clone/features/explore/data/datasources/explore_remote_datasource.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExploreRemoteDataSourceImpl implements ExploreRemoteDataSource {
  final SupabaseClient supabaseClient;

  ExploreRemoteDataSourceImpl({required this.supabaseClient});

  // Treat user input as text, rather than as an ILIKE wildcard pattern.
  String _pattern(String value) =>
      '%${value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';

  @override
  Future<List<Post>> getExplorePosts(
      {int limit = 24, int offset = 0, String query = ''}) async {
    final posts = supabaseClient
        .from(SupabaseConstants.postsTable)
        .select(PostModel.columns);
    final filtered =
        query.isEmpty ? posts : posts.ilike('description', _pattern(query));
    final response = await filtered
        .order('created_at', ascending: false, nullsFirst: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return response.map(PostModel.fromJson).toList();
  }

  @override
  Future<List<app_user.User>> searchUsers(String query) async {
    final response = await supabaseClient
        .from(SupabaseConstants.usersTable)
        .select(SupabaseConstants.publicUserColumns)
        .ilike('username', _pattern(query))
        .order('username')
        .limit(20);
    return response.map(UserModel.fromJson).toList();
  }
}
