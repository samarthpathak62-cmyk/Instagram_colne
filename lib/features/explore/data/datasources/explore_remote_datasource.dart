import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';

abstract class ExploreRemoteDataSource {
  Future<List<Post>> getExplorePosts(
      {int limit = 24, int offset = 0, String query = ''});
  Future<List<User>> searchUsers(String query);
}
