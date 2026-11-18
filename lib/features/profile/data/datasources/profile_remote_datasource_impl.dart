import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/media/supabase_media_upload.dart';
import 'package:instagram_clone/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:instagram_clone/features/profile/data/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient supabaseClient;

  ProfileRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final row =
          await supabaseClient.from(SupabaseConstants.usersTable).select('''
        id,username,full_name,bio,profile_picture_url,
        followers:followers!followers_following_id_fkey(count),
        following:followers!followers_follower_id_fkey(count),
        posts(count)
      ''').eq('id', userId).single();
      return ProfileModel.fromJson(row);
    } on PostgrestException catch (error) {
      throw ServerException(
          message: 'Could not load profile: ${error.message}');
    }
  }

  @override
  Future<ProfileModel> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    XFile? profileImage,
  }) async {
    try {
      final imageUrl = profileImage == null
          ? null
          : await uploadPublicMedia(
              client: supabaseClient,
              file: profileImage,
              bucket: SupabaseConstants.profileImagesBucket,
              ownerId: userId,
            );
      final updates = {
        if (username != null) 'username': username,
        if (fullName != null) 'full_name': fullName,
        if (bio != null) 'bio': bio,
        if (imageUrl != null) 'profile_picture_url': imageUrl,
      };
      if (updates.isNotEmpty) {
        await supabaseClient
            .from(SupabaseConstants.usersTable)
            .update(updates)
            .eq('id', userId)
            .select('id')
            .single();
      }
      return await getProfile(userId);
    } on PostgrestException catch (error) {
      throw ServerException(
          message: error.code == '23505'
              ? 'That username is taken.'
              : 'Could not update profile: ${error.message}');
    } on StorageException catch (error) {
      throw ServerException(
          message: 'Could not upload profile photo: ${error.message}');
    } on FileUploadException catch (error) {
      throw ServerException(message: error.message);
    }
  }
}
