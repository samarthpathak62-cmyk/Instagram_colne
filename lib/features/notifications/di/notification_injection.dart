import 'package:get_it/get_it.dart';
import 'package:instagram_clone/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:instagram_clone/features/notifications/data/datasources/notification_remote_datasource_impl.dart';
import 'package:instagram_clone/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:instagram_clone/features/notifications/domain/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void registerNotificationDependencies(GetIt sl) {
  // Repository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: sl()),
  );

  // Data source
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () =>
        NotificationRemoteDataSourceImpl(supabaseClient: sl<SupabaseClient>()),
  );
}
