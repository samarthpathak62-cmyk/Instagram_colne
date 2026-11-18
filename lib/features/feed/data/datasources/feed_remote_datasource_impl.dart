import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
// lib/features/feed/data/datasources/feed_remote_datasource_impl.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/feed_item.dart';
import '../models/feed_item_model.dart'; // Assuming FeedItemModel is defined
import 'feed_remote_datasource.dart';

/// Implementation of [FeedRemoteDataSource] that interacts with Supabase.
class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  final SupabaseClient supabaseClient;

  FeedRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<FeedItem>> getFeed({int page = 0, int limit = 10}) async {
    try {
      final offset = page * limit;
      final viewer = supabaseClient.auth.currentUser?.id;
      final posts = supabaseClient.from(SupabaseConstants.postsTable);
      final query = viewer == null
          ? posts.select(PostModel.columns)
          : posts
              .select(PostModel.columnsWithViewer)
              .eq('liked_by_user.user_id', viewer);
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map(FeedItemModel.fromJson).toList();
    } on PostgrestException catch (e) {
      throw SupabaseException(message: e.message, code: e.code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<FeedItem>> refreshFeed() async {
    // For refresh, we typically fetch the latest items,
    // often the first page or a slightly larger set to catch new content.
    // This example reuses getFeed for simplicity, fetching the first page.
    return getFeed();
  }
}
