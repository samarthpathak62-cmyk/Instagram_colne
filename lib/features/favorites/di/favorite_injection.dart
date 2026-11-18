import 'package:get_it/get_it.dart';
import 'package:instagram_clone/features/favorites/data/datasources/favorite_remote_datasource.dart';
import 'package:instagram_clone/features/favorites/data/datasources/favorite_remote_datasource_impl.dart';

import 'package:instagram_clone/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:instagram_clone/features/favorites/domain/repositories/favorite_repository.dart';

void registerFavoriteDependencies(GetIt sl) {
  // Repository
  sl.registerLazySingleton<FavoriteRepository>(
    () => FavoriteRepositoryImpl(
      remoteDataSource: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<FavoriteRemoteDataSource>(
    () => FavoriteRemoteDataSourceImpl(
      supabaseClient: sl(),
    ),
  );
}
