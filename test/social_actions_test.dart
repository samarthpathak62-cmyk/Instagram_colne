import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/feed/data/datasources/feed_remote_datasource_impl.dart';
import 'package:instagram_clone/features/feed/data/models/feed_item_model.dart';
import 'package:instagram_clone/features/feed/domain/entities/feed_item.dart';
import 'package:instagram_clone/features/feed/domain/repositories/feed_repository.dart';
import 'package:instagram_clone/features/feed/domain/usecases/get_feed.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_state.dart';
import 'package:instagram_clone/features/post/data/datasources/post_remote_datasource_impl.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/domain/entities/post_comment.dart';
import 'package:instagram_clone/features/post/domain/repositories/post_repository.dart';
import 'package:instagram_clone/features/post/domain/usecases/create_post.dart';
import 'package:instagram_clone/features/post/domain/usecases/get_post.dart';
import 'package:instagram_clone/features/post/domain/usecases/get_user_posts.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/post_links.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const _postId = '00000000-0000-4000-8000-000000000123';
const _viewer = 'test-viewer';

Map<String, dynamic> _row([String id = _postId]) => {
      'id': id,
      'author_id': _viewer,
      'type': 'text',
      'description': 'First text update',
      'media_urls': [],
      'created_at': '2026-11-18T06:00:00Z',
      'author': {'id': _viewer, 'username': 'veyro_test'},
      'likes': [
        {'count': 2}
      ],
      'comments': [
        {'count': 0}
      ],
    };

supabase.SupabaseClient _client(MockClient transport) =>
    supabase.SupabaseClient(
      'https://example.invalid',
      'test-key',
      httpClient: transport,
      authOptions: const supabase.AuthClientOptions(
        authFlowType: supabase.AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

void main() {
  test(
      'text composer writes a post but no storage object; blank text is rejected',
      () async {
    var requests = 0;
    final client = _client(MockClient((request) async {
      requests++;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/posts');
      expect(jsonDecode(request.body), {
        'author_id': _viewer,
        'type': 'text',
        'media_urls': [],
        'description': 'First text update',
      });
      return http.Response(jsonEncode(_row()), 201,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final remote = PostRemoteDataSourceImpl(supabaseClient: client);
    final result = await remote.createPost(
        authorId: _viewer,
        type: PostType.text,
        mediaFiles: [],
        description: ' First text update  ');
    expect(result.type, PostType.text);
    expect(result.mediaUrl, isNull);
    await expectLater(
        remote.createPost(
            authorId: _viewer,
            type: PostType.text,
            mediaFiles: [],
            description: '   '),
        throwsA(isA<ServerException>()));
    expect(requests, 1);
  });

  test('photo and reel files use the owner folder and attach public media URLs',
      () async {
    final paths = <String>[];
    final client = _client(MockClient((request) async {
      expect(request.method, 'POST');
      if (request.url.path.startsWith('/storage/v1/object/post-media/')) {
        final asset = request.url.path.replaceFirst('/storage/v1/object/', '');
        expect(asset, startsWith('post-media/$_viewer/'));
        paths.add(asset);
        return http.Response(jsonEncode({'Key': asset}), 200,
            headers: {'content-type': 'application/json'});
      }
      expect(request.url.path, '/rest/v1/posts');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final urls = body['media_urls'] as List;
      expect(urls,
          ['https://example.invalid/storage/v1/object/public/${paths.last}']);
      return http.Response(jsonEncode({..._row(), ...body}), 201,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    String b64(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    await client.auth.recoverSession(jsonEncode({
      'access_token':
          '${b64({'alg': 'HS256'})}.${b64({'sub': _viewer, 'exp': exp})}.test',
      'expires_in': 3600,
      'token_type': 'bearer',
      'refresh_token': 'fixture',
      'user': {
        'id': _viewer,
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-11-18T06:00:00Z',
        'aud': 'authenticated'
      },
    }));
    final remote = PostRemoteDataSourceImpl(supabaseClient: client);
    for (final pair in [
      (PostType.image, 'photo.png'),
      (PostType.video, 'reel.mp4')
    ]) {
      final result = await remote.createPost(
          authorId: _viewer,
          type: pair.$1,
          mediaFiles: [
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: pair.$2)
          ],
          description: 'A media post');
      expect(result.type, pair.$1);
    }
    expect(paths.length, 2);
    expect(paths.first, endsWith('.png'));
    expect(paths.last, endsWith('.mp4'));
  });

  test('following feed calls the server filter and still projects text posts',
      () async {
    final client = _client(MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/rpc/veyro_following_posts');
      expect(request.url.queryParameters['select'],
          contains('author:users!posts_author_id_fkey'));
      expect(request.url.queryParameters['offset'], '10');
      expect(request.url.queryParameters['limit'], '10');
      return http.Response(jsonEncode([_row()]), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final remote = FeedRemoteDataSourceImpl(supabaseClient: client);
    final posts = await remote.getFeed(page: 1, following: true);
    expect(posts.single.toPost().type, PostType.text);
    expect(posts.single.toPost().description, 'First text update');
  });

  test('post detail loads directly from its repository, with viewer save data',
      () async {
    final post = PostModel.fromJson({
      ..._row(),
      'saved_by_user': [
        {'id': 'saved-row'}
      ]
    });
    final repository = _PostRepository(post);
    final bloc = PostBloc(
        createPost: CreatePost(repository),
        getPost: GetPost(repository),
        getUserPosts: GetUserPosts(repository));
    addTearDown(bloc.close);
    final future = expectLater(bloc.stream,
        emitsInOrder([isA<PostsLoading>(), PostDetailLoaded(post)]));
    bloc.add(const LoadPostDetail(postId: _postId));
    await future;
    expect(post.isSavedByCurrentUser, isTrue);
  });

  test('feed ignores a late Latest response and appends Following pages',
      () async {
    final repository = _FeedRepository();
    final cubit = FeedCubit(GetFeed(repository));
    addTearDown(cubit.close);
    final latest = cubit.refresh();
    final following = cubit.selectTimeline(FeedTimeline.following);
    final results = List.generate(
        10, (index) => FeedItemModel.fromJson(_row('following-$index')));
    repository.following.complete(Right(results));
    await following;
    repository.latest.complete(Right([FeedItemModel.fromJson(_row('latest'))]));
    await latest;
    expect(cubit.state.timeline, FeedTimeline.following);
    expect(cubit.state.items, results);
    await cubit.loadMore();
    expect(cubit.state.items.length, 11);
    expect(cubit.state.items.last.id, 'following-next');
    expect(cubit.state.hasMore, isFalse);
  });

  test('failed like rolls back without losing a successful save', () async {
    final post = PostModel.fromJson(_row());
    final repository = _PostRepository(post);
    final actions =
        PostInteractionsCubit(repository: repository, userId: _viewer);
    addTearDown(actions.close);
    final like = actions.toggleLike(post);
    expect(actions.forPost(post.id).likes(post), 3);
    expect(actions.forPost(post.id).liking, isTrue);
    await actions.toggleLike(post);
    expect(repository.likeCalls, 1);
    expect(await actions.toggleSave(post), isNull);
    repository.like.complete(const Left(ServerFailure(message: 'Like failed')));
    expect(await like, 'Like failed');
    expect(actions.forPost(post.id).likes(post), 2);
    expect(actions.forPost(post.id).isSaved(post), isTrue);
    // A freshly loaded snapshot from another screen must not double-count a viewer like.
    final current = PostInteraction(liked: true);
    final refreshed = PostModel.fromJson({
      ..._row(),
      'liked_by_user': [
        {'user_id': _viewer}
      ],
      'likes': [
        {'count': 3}
      ]
    });
    expect(current.likes(refreshed), 3);
  });

  testWidgets('post comments can be written, reloaded and removed',
      (tester) async {
    final post = PostModel.fromJson(_row());
    final repo = _PostRepository(post);
    final actions = PostInteractionsCubit(repository: repo, userId: _viewer);
    addTearDown(actions.close);
    await tester.pumpWidget(BlocProvider.value(
      value: actions,
      child: MaterialApp(
          home: Scaffold(body: ListView(children: [PostCard(post: post)]))),
    ));
    await tester.ensureVisible(find.byTooltip('Comments'));
    await tester.tap(find.byTooltip('Comments'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No comments yet'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nice update!');
    await tester.pump();
    await tester.tap(find.byTooltip('Send comment'));
    await tester.pumpAndSettle();
    expect(find.text('Nice update!'), findsOneWidget);
    expect(actions.forPost(_postId).commentCount, 1);
    await tester.tap(find.byTooltip('Delete comment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Nice update!'), findsNothing);
    expect(actions.forPost(_postId).commentCount, 0);
    expect(tester.takeException(), isNull);
  });

  test(
      'portable post links are recognized without treating other hosts as Veyro',
      () {
    final link = PostLinks.link(_postId, portable: true);
    expect(PostLinks.read(link), _postId);
    expect(PostLinks.inMessage(link.toString()), _postId);
    expect(
        PostLinks.inMessage(link.replace(host: 'example.invalid').toString()),
        isNull);
    expect(PostLinks.read(link.replace(queryParameters: {'post': 'wrong'})),
        isNull);
  });
}

class _FeedRepository implements FeedRepository {
  final latest = Completer<Either<Failure, List<FeedItem>>>();
  final following = Completer<Either<Failure, List<FeedItem>>>();

  @override
  Future<Either<Failure, List<FeedItem>>> getFeed(
      {int page = 0, int limit = 10, bool following = false}) async {
    if (page > 0)
      return Right([FeedItemModel.fromJson(_row('following-next'))]);
    return (following ? this.following : latest).future;
  }
}

class _PostRepository implements PostRepository {
  final Post post;
  final comments = <PostComment>[];
  final like = Completer<Either<Failure, void>>();
  int likeCalls = 0;

  _PostRepository(this.post);

  @override
  Future<Either<Failure, Post>> getPost(String postId) async => Right(post);

  @override
  Future<Either<Failure, void>> likePost(String postId, String userId) {
    likeCalls++;
    return like.future;
  }

  @override
  Future<Either<Failure, void>> setSaved(
          String postId, String userId, bool saved) async =>
      const Right(null);

  @override
  Future<Either<Failure, CommentPage>> getComments(String postId,
          {int offset = 0}) async =>
      Right(CommentPage(List.of(comments), comments.length));

  @override
  Future<Either<Failure, PostComment>> addComment(
      String postId, String userId, String content) async {
    final item = PostComment(
        id: 'c1',
        postId: postId,
        userId: userId,
        content: content,
        createdAt: DateTime.now());
    comments.add(item);
    return Right(item);
  }

  @override
  Future<Either<Failure, void>> deleteComment(
      String commentId, String userId) async {
    comments
        .removeWhere((item) => item.id == commentId && item.userId == userId);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} not used in test');
}
