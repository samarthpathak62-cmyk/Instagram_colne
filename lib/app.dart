import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/screens/login_screen.dart';
import 'package:instagram_clone/features/auth/presentation/screens/splash_screen.dart';
import 'package:instagram_clone/features/common_widgets/main_navigation_screen.dart';

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    // Define light and dark themes later in core/theme
    return MaterialApp(
      title: 'Instagram Clone',
      theme: ThemeData.light(), // Placeholder
      darkTheme: ThemeData.dark(), // Placeholder
      themeMode: ThemeMode.system, // Or load from settings
      debugShowCheckedModeBanner: false,
      // Add localization delegates later
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
