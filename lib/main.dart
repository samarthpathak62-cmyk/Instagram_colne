import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/app.dart';
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/notifications/presentation/bloc/activity_cubit.dart';
import 'package:instagram_clone/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
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
              BlocProvider<ChatBloc>(
                  create: (_) => di.sl<ChatBloc>()
                    ..add(LoadChatsEvent(userId: userId))
                    ..add(SubscribeToChatsEvent(userId: userId))),
              BlocProvider<ActivityCubit>(
                  create: (_) =>
                      ActivityCubit(repository: di.sl(), userId: userId)
                        ..start()),
              BlocProvider<PostInteractionsCubit>(
                create: (_) =>
                    PostInteractionsCubit(repository: di.sl(), userId: userId),
              ),
              BlocProvider<FeedCubit>(
                  create: (_) => di.sl<FeedCubit>()..refresh()),
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
