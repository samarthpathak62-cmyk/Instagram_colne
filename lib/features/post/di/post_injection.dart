// lib/features/post/di/post_injection.dart

import 'package:get_it/get_it.dart';

import '../data/datasources/post_remote_datasource.dart';
import '../data/datasources/post_remote_datasource_impl.dart';
import '../data/repositories/post_repository_impl.dart';
import '../domain/repositories/post_repository.dart';
import '../domain/usecases/create_post.dart';
import '../domain/usecases/get_post.dart';
import '../domain/usecases/get_user_posts.dart';
import '../presentation/bloc/post_bloc.dart';

/// Registers all the dependencies for the Post feature.
void initPost(GetIt sl) {
  // Bloc
  sl.registerFactory(
    () => PostBloc(
      createPost: sl(),
      getPost: sl(),
      getUserPosts: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => CreatePost(sl()));
  sl.registerLazySingleton(() => GetPost(sl()));
  sl.registerLazySingleton(() => GetUserPosts(sl()));

  // Repository
  sl.registerLazySingleton<PostRepository>(
    () => PostRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<PostRemoteDataSource>(
    () => PostRemoteDataSourceImpl(supabaseClient: sl()),
  );
}
