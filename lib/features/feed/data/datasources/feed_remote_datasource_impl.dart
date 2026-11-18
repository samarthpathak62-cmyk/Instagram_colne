import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/features/feed/data/models/feed_item_model.dart';
import 'package:instagram_clone/features/feed/domain/entities/feed_item.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_remote_datasource.dart';

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final SupabaseClient supabaseClient;

  FeedRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<FeedItem>> getFeed(
      {int page = 0, int limit = 10, bool following = false}) async {
    try {
      final viewer = supabaseClient.auth.currentUser?.id;
      final columns =
          viewer == null ? PostModel.columns : PostModel.columnsWithViewer;
      // The table-shaped endpoint avoids the PostgREST RPC projection bug
      // when filtering the embedded likes and private saves by viewer.
      final query = supabaseClient
          .from(
              following ? 'veyro_following_feed' : SupabaseConstants.postsTable)
          .select(columns);
      final scoped = viewer == null
          ? query
          : query
              .eq('liked_by_user.user_id', viewer)
              .eq('saved_by_user.user_id', viewer);
      final response = await scoped
          .order('created_at', ascending: false, nullsFirst: false)
          .order('id', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      return response.map(FeedItemModel.fromJson).toList();
    } on PostgrestException catch (error) {
      throw SupabaseException(message: error.message, code: error.code);
    } catch (_) {
      throw ServerException(message: 'Could not load the feed. Try again.');
    }
  }
}
