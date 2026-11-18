import 'package:dartz/dartz.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/profile/domain/entities/profile.dart';
import 'package:image_picker/image_picker.dart' show XFile;

abstract class ProfileRepository {
  Future<Either<Failure, Profile>> getProfile(String userId);

  Future<Either<Failure, Profile>> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    XFile? profileImage, // Pass XFile object for new image
  });

  // Add other profile-related methods if needed, e.g.:
  // Future<Either<Failure, List<Post>>> getUserPosts(String userId);
  // Future<Either<Failure, void>> followUser(String userIdToFollow);
  // Future<Either<Failure, void>> unfollowUser(String userIdToUnfollow);
}
