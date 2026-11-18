import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/generated/app_localizations.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/screens/login_screen.dart';
import 'package:instagram_clone/features/auth/presentation/screens/splash_screen.dart';
import 'package:instagram_clone/features/common_widgets/main_navigation_screen.dart';

class AppView extends StatelessWidget {
  final ThemeMode themeMode;
  final Locale? locale;

  const AppView({super.key, this.themeMode = ThemeMode.dark, this.locale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: VeyroTheme.light,
      darkTheme: VeyroTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Authenticated) {
            return const MainNavigationScreen();
          }
          if (state is AuthInitial) {
            return const SplashScreen();
          }
          // Keep the sign-in form mounted during a request so its listener can
          // show the response and the form keeps its inputs on failure.
          return const LoginScreen();
        },
      ),
    );
  }
}
