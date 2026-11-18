import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/follow/data/datasources/follow_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class FollowRemoteDataSourceImpl implements FollowRemoteDataSource {
  final supabase.SupabaseClient supabaseClient;
  FollowRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<void> followUser(
      {required String followerId, required String followingId}) async {
    if (followerId == followingId) return;
    try {
      await supabaseClient.from(SupabaseConstants.followersTable).insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
    } on supabase.PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  @override
  Future<void> unfollowUser(
      {required String followerId, required String followingId}) async {
    await supabaseClient.from(SupabaseConstants.followersTable).delete().match({
      'follower_id': followerId,
      'following_id': followingId,
    });
  }

  @override
  Future<List<User>> getFollowers(String userId) async {
    final rows = await supabaseClient
        .from(SupabaseConstants.followersTable)
        .select(
            'person:users!followers_follower_id_fkey(${SupabaseConstants.publicUserColumns})')
        .eq('following_id', userId);
    return rows
        .map((row) => UserModel.fromJson(row['person'] as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<User>> getFollowing(String userId) async {
    final rows = await supabaseClient
        .from(SupabaseConstants.followersTable)
        .select(
            'person:users!followers_following_id_fkey(${SupabaseConstants.publicUserColumns})')
        .eq('follower_id', userId);
    return rows
        .map((row) => UserModel.fromJson(row['person'] as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> checkFollowStatus(
      {required String currentUserId, required String targetUserId}) async {
    final row = await supabaseClient
        .from(SupabaseConstants.followersTable)
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return row != null;
  }
}
