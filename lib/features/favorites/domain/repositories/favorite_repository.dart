import 'package:dartz/dartz.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/favorites/domain/entities/favorite.dart';

abstract class FavoriteRepository {
  Future<Either<Failure, List<Favorite>>> getFavorites(String userId);
}
