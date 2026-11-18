import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/constants/app_constants.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/generated/app_localizations.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/screens/login_screen.dart';
import 'package:instagram_clone/features/auth/presentation/screens/splash_screen.dart';
import 'package:instagram_clone/features/common_widgets/main_navigation_screen.dart';
import 'package:instagram_clone/features/post/presentation/post_links.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';

class AppView extends StatelessWidget {
  final ThemeMode themeMode;
  final Locale? locale;

  const AppView({super.key, this.themeMode = ThemeMode.light, this.locale});

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
            return const _SignedInHome();
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

class _SignedInHome extends StatefulWidget {
  const _SignedInHome();

  @override
  State<_SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<_SignedInHome> {
  @override
  void initState() {
    super.initState();
    final postId = kIsWeb ? PostLinks.read(Uri.base) : null;
    if (postId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PostDetailScreen(postId: postId)));
      });
    }
  }

  @override
  Widget build(BuildContext context) => const MainNavigationScreen();
}
