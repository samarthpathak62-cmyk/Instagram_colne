import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:instagram_clone/app.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/data/datasources/auth_remote_datasource_impl.dart';
import 'package:instagram_clone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:instagram_clone/features/auth/domain/usecases/get_current_user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/login_user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/signup_user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  test('Veyro palettes keep text and controls readable', () {
    for (final theme in [VeyroTheme.dark, VeyroTheme.light]) {
      final scheme = theme.colorScheme;
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHigh),
        greaterThan(4.5),
      );
      expect(
        _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThan(4.5),
      );
    }
    expect(_contrast(Colors.white, VeyroTheme.blue), greaterThan(4.5));
  });

  group('Veyro entry screens', () {
    late AuthBloc auth;

    // Set up and close the SDK outside the fake clock used for widget frames.
    setUp(() async {
      final client = supabase.SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((_) async => http.Response('{}', 500)),
        authOptions: const supabase.AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final repository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSourceImpl(supabaseClient: client),
      );
      auth = AuthBloc(
        loginUser: LoginUser(repository),
        signupUser: SignupUser(repository),
        getCurrentUser: GetCurrentUser(repository),
        supabaseClient: client,
      );
      addTearDown(auth.close);
      if (auth.state is! Unauthenticated) {
        await auth.stream.firstWhere((state) => state is Unauthenticated);
      }
    });

    for (final size in [const Size(360, 740), const Size(1360, 860)]) {
      testWidgets('branded auth is usable at ${size.width.toInt()}px',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
            BlocProvider.value(value: auth, child: const AppView()));
        await tester.pumpAndSettle();
        expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
            'Veyro');
        expect(find.byType(VeyroMark), findsOneWidget);
        expect(find.text('Welcome back'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
        await tester.pumpAndSettle();
        expect(find.text('Enter your email address.'), findsOneWidget);
        expect(find.text('Enter your password.'), findsOneWidget);

        final signup = find.text('Create an account');
        await tester.ensureVisible(signup);
        await tester.tap(signup);
        await tester.pumpAndSettle();
        expect(find.text('Join Veyro'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(tester.takeException(), isNull);

        final showPassword = find.byTooltip('Show password');
        await tester.ensureVisible(showPassword);
        await tester.tap(showPassword);
        await tester.pump();
        expect(find.byTooltip('Hide password'), findsOneWidget);
        final back = find.text('Log in');
        await tester.ensureVisible(back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}
