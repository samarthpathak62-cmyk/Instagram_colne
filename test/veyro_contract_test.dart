import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/auth/data/datasources/auth_remote_datasource_impl.dart';
import 'package:instagram_clone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:instagram_clone/features/auth/domain/usecases/get_current_user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/login_user.dart';
import 'package:instagram_clone/features/auth/domain/usecases/signup_user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/screens/splash_screen.dart';
import 'package:instagram_clone/features/feed/data/models/feed_item_model.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/profile/data/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  testWidgets('auth startup can leave the splash without a pending animation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  test('public Veyro posts parse without an author email or viewer like', () {
    final row = <String, dynamic>{
      'id': 'post-1',
      'author_id': 'author-1',
      'author': {
        'id': 'author-1',
        'username': 'veyro',
        'profile_picture_url': 'https://example.invalid/avatar.jpg',
      },
      'description': 'First photo',
      'type': 'image',
      'media_urls': ['https://example.invalid/photo.jpg'],
      'created_at': '2026-11-18T07:00:00Z',
      'likes': [
        {'count': 4}
      ],
      'comments': [
        {'count': 2}
      ],
      'liked_by_user': [],
    };

    final post = PostModel.fromJson(row);
    expect(post.author?.username, 'veyro');
    expect(post.author?.email, isEmpty);
    expect(post.isLikedByCurrentUser, isFalse);

    row['liked_by_user'] = [
      {'user_id': 'viewer'}
    ];
    final feedPost = FeedItemModel.fromJson(row).toPost();
    expect(feedPost.type, PostType.image);
    expect(feedPost.mediaUrls, row['media_urls']);
    expect(feedPost.caption, 'First photo');
    expect(feedPost.likeCount, 4);
    expect(feedPost.commentCount, 2);
    expect(feedPost.isLikedByCurrentUser, isTrue);
  });

  test('an account can have no public username until the owner picks one', () {
    final profile = ProfileModel.fromJson({
      'id': 'new-user',
      'username': null,
      'full_name': 'New User',
      'profile_picture_url': 'https://example.invalid/avatar.jpg',
      'followers': [
        {'count': 3}
      ],
      'following': [
        {'count': 2}
      ],
      'posts': [
        {'count': 1}
      ],
    });
    expect(profile.username, 'User');
    expect(profile.fullName, 'New User');
    expect(profile.profileImageUrl, 'https://example.invalid/avatar.jpg');
    expect([profile.followerCount, profile.followingCount, profile.postCount],
        [3, 2, 1]);
  });

  test(
      'signup sends Veyro metadata and does not authenticate an unconfirmed email',
      () async {
    const email = 'test@example.invalid';
    final httpClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/v1/signup');
      expect(request.url.queryParameters['redirect_to'],
          SupabaseConstants.emailRedirectUrl);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], email);
      expect(body['password'], '  test-only password  ');
      expect(body['data'], {
        'username': 'veyro',
        'full_name': 'Veyro User',
        'display_name': 'Veyro User'
      });
      return http.Response(
          jsonEncode({'id': 'unconfirmed-user', 'email': email}), 200,
          headers: {'content-type': 'application/json'});
    });
    final client =
        supabase.SupabaseClient('https://example.invalid', 'test-key',
            httpClient: httpClient,
            authOptions: const supabase.AuthClientOptions(
              authFlowType: supabase.AuthFlowType.implicit,
              autoRefreshToken: false,
            ));
    addTearDown(client.dispose);
    final repository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(supabaseClient: client),
    );
    final bloc = AuthBloc(
      loginUser: LoginUser(repository),
      signupUser: SignupUser(repository),
      getCurrentUser: GetCurrentUser(repository),
      supabaseClient: client,
    );
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((state) => state is Unauthenticated);

    final result = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          const AuthEmailConfirmationRequired(email),
        ]));
    bloc.add(const AuthSignupRequested(
        email: email,
        password: '  test-only password  ',
        username: 'veyro',
        fullName: 'Veyro User'));
    await result;
    expect(client.auth.currentSession, isNull);
  });
}
