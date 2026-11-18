import 'package:dartz/dartz.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/core/usecase/usecase.dart';
import 'package:instagram_clone/features/favorites/domain/repositories/favorite_repository.dart';

class GetSavedPostId implements UseCase<String?, GetSavedPostIdParams> {
  final FavoriteRepository repository;

  GetSavedPostId(this.repository);

  @override
  Future<Either<Failure, String?>> call(GetSavedPostIdParams params) async {
    return await repository.getSavedPostId(params.userId, params.postId);
  }
}

class GetSavedPostIdParams extends NoParams {
  final String userId;
  final String postId;

  GetSavedPostIdParams({
    required this.userId,
    required this.postId,
  });

  @override
  List<Object> get props => [userId, postId];
}
