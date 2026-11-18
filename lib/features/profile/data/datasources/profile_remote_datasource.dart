import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/features/profile/data/models/profile_model.dart'; // To be created

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    XFile? profileImage,
  });
}
