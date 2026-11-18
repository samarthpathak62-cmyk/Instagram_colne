import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/media/supabase_media_upload.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/story/data/datasources/story_remote_datasource.dart';
import 'package:instagram_clone/features/story/data/models/story_model.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryRemoteDataSourceImpl implements StoryRemoteDataSource {
  final SupabaseClient supabaseClient;

  StoryRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<void> createStoryItem({
    required String userId,
    required XFile mediaFile,
    required StoryMediaType mediaType,
  }) async {
    try {
      final mediaUrl = await uploadPublicMedia(
        client: supabaseClient,
        file: mediaFile,
        bucket: SupabaseConstants.storyMediaBucket,
        ownerId: userId,
        isVideo: mediaType == StoryMediaType.video,
      );
      await supabaseClient.rpc('veyro_add_story_item', params: {
        'p_media_url': mediaUrl,
        'p_media_type': mediaType.name,
      });
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not publish story: ${error.message}');
    } on StorageException catch (error) {
      throw ServerException(
          message: 'Could not upload story: ${error.message}');
    } on FileUploadException catch (error) {
      throw ServerException(message: error.message);
    }
  }

  @override
  Future<List<StoryModel>> getStories(String currentUserId) async {
    try {
      final following = await supabaseClient
          .from(SupabaseConstants.followersTable)
          .select('following_id')
          .eq('follower_id', currentUserId);
      final authors = [
        currentUserId,
        ...following.map((row) => row['following_id'] as String)
      ];
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      final rows = await supabaseClient
          .from('stories')
          .select('''
        user_id,
        author:users!stories_user_id_fkey(${SupabaseConstants.publicUserColumns}),
        items:story_items!inner(id,media_url,media_type,created_at)
      ''')
          .inFilter('user_id', authors)
          .gte('items.created_at', cutoff.toIso8601String());

      final authorById = <String, UserModel>{};
      final itemsByAuthor = <String, List<StoryItemModel>>{};
      for (final row in rows) {
        final userId = row['user_id'] as String;
        final author = row['author'] as Map<String, dynamic>?;
        if (author != null) authorById[userId] = UserModel.fromJson(author);
        final items = (row['items'] as List).cast<Map<String, dynamic>>();
        itemsByAuthor
            .putIfAbsent(userId, () => [])
            .addAll(items.map(StoryItemModel.fromJson));
      }
      final stories = itemsByAuthor.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) {
        final author = authorById[entry.key];
        final items = entry.value
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return StoryModel(
          id: entry.key,
          userId: entry.key,
          author: author,
          username: author?.username,
          userProfilePictureUrl: author?.profilePictureUrl,
          userProfileImageUrl: author?.profilePictureUrl,
          items: items,
          lastUpdatedAt: items.last.createdAt,
        );
      }).toList()
        ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
      return stories;
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not load stories: ${error.message}');
    }
  }
}
