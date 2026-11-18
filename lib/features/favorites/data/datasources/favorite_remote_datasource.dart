import 'package:instagram_clone/features/favorites/data/models/favorite_model.dart';

abstract class FavoriteRemoteDataSource {
  Future<List<FavoriteModel>> getFavorites(String userId);
}
