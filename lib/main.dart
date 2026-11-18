import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/app.dart';
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:instagram_clone/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/manrope/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Manrope'], license);
  });

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabasePublishableKey,
  );

  // Initialize Dependency Injection
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => di.sl<AuthBloc>(),
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, next) => _userId(previous) != _userId(next),
        builder: (context, state) {
          final userId = _userId(state);
          if (userId == null) return const AppView();
          return MultiBlocProvider(
            key: ValueKey(userId),
            providers: [
              BlocProvider<FeedBloc>(create: (_) => di.sl<FeedBloc>()),
              BlocProvider<ExploreBloc>(
                  create: (_) =>
                      di.sl<ExploreBloc>()..add(const LoadExplorePostsEvent())),
              BlocProvider<NotificationBloc>(
                  create: (_) => di.sl<NotificationBloc>()),
              BlocProvider<SettingsBloc>(
                create: (_) => di.sl<SettingsBloc>()
                  ..add(GetSettingsEvent(userId: userId)),
              ),
            ],
            child: BlocBuilder<SettingsBloc, SettingsState>(
              // Keep the applied theme while a preference update is in flight.
              buildWhen: (_, next) => next is SettingsLoaded,
              builder: (context, state) => AppView(
                locale: state is SettingsLoaded
                    ? Locale(state.settings.language)
                    : null,
                themeMode: state is SettingsLoaded
                    ? state.settings.flutterThemeMode
                    : ThemeMode.dark,
              ),
            ),
          );
        },
      ),
    );
  }

  String? _userId(AuthState state) =>
      state is Authenticated ? state.user.id : null;
}
