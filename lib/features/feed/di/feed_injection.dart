import 'package:get_it/get_it.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';

import '../domain/repositories/feed_repository.dart';
import '../domain/usecases/get_feed.dart';
import '../data/repositories/feed_repository_impl.dart';
import '../data/datasources/feed_remote_datasource.dart';
import '../data/datasources/feed_remote_datasource_impl.dart';

final sl = GetIt.instance;

Future<void> initFeedDependencies() async {
  sl.registerFactory(() => FeedCubit(sl()));
  sl.registerLazySingleton(() => GetFeed(sl()));

  // Repository
  sl.registerLazySingleton<FeedRepository>(
    () => FeedRepositoryImpl(remoteDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<FeedRemoteDataSource>(
    () => FeedRemoteDataSourceImpl(supabaseClient: sl()),
  );
}
