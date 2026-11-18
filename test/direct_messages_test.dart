import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/entities/message.dart';
import 'package:instagram_clone/features/chat/domain/repositories/chat_repository.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_chats.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_messages.dart';
import 'package:instagram_clone/features/chat/domain/usecases/mark_messages_as_read.dart';
import 'package:instagram_clone/features/chat/domain/usecases/send_message.dart';
import 'package:instagram_clone/features/chat/domain/usecases/subscribe_to_chats.dart';
import 'package:instagram_clone/features/chat/domain/usecases/subscribe_to_messages.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chat_detail_screen.dart';

const _me = User(id: 'me', email: '', username: 'veyro_me');
const _friend = User(
    id: 'friend', email: '', username: 'veyro_friend', name: 'Veyro Friend');
final _timestamp = DateTime.utc(2026, 11, 18, 12);
final _chat = Chat(
    id: 'chat',
    user1Id: _me.id,
    user2Id: _friend.id,
    lastMessageTime: _timestamp,
    hasUnreadMessages: true,
    otherUser: _friend,
    lastMessageContent: 'Welcome!');

class _ChatFixture implements ChatRepository {
  var incoming = Message(
      id: 'incoming',
      chatId: _chat.id,
      senderId: _friend.id,
      receiverId: _me.id,
      content: 'Welcome!',
      timestamp: _timestamp,
      isRead: false);
  Message? outgoing;
  bool failSend = true;
  List<String>? readRequest;

  @override
  Future<Either<Failure, List<Chat>>> getChats(String userId) async =>
      Right([_chat]);
  @override
  Future<Either<Failure, Chat>> getChatById(String chatId) async =>
      Right(_chat);
  @override
  Future<Either<Failure, Chat>> getOrCreateChat(
          String currentUserId, String otherUserId) async =>
      Right(_chat);
  @override
  Future<Either<Failure, List<Message>>> getMessages(String chatId) async =>
      Right([incoming, if (outgoing != null) outgoing!]);
  @override
  Future<Either<Failure, bool>> markMessagesAsRead(
      String chatId, String userId) async {
    readRequest = [chatId, userId];
    incoming = incoming.asRead();
    return const Right(true);
  }

  @override
  Future<Either<Failure, Message>> sendMessage(
      String chatId, String senderId, String receiverId, String content) async {
    if (failSend) return const Left(ServerFailure(message: 'Offline'));
    outgoing = Message(
        id: 'outgoing',
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        timestamp: _timestamp.add(const Duration(minutes: 1)),
        isRead: false);
    return Right(outgoing!);
  }

  @override
  Stream<Either<Failure, Message>> subscribeToMessages(String chatId) =>
      const Stream.empty();
  @override
  Stream<Either<Failure, List<Chat>>> subscribeToChats(String userId) =>
      const Stream.empty();
}

void main() {
  testWidgets('viewing a thread marks it read; a failed send keeps the draft',
      (tester) async {
    final fixture = _ChatFixture();
    final bloc = ChatBloc(
        getChats: GetChats(fixture),
        getMessages: GetMessages(fixture),
        sendMessage: SendMessage(fixture),
        markMessagesAsRead: MarkMessagesAsRead(fixture),
        subscribeToMessages: SubscribeToMessages(fixture),
        subscribeToChats: SubscribeToChats(fixture));
    var read = 0;
    var sent = 0;
    await tester.pumpWidget(MaterialApp(
        theme: VeyroTheme.dark,
        home: BlocProvider.value(
            value: bloc,
            child: ChatDetailScreen(
                chat: _chat,
                currentUser: _me,
                onRead: () => read++,
                onMessageSent: () => sent++))));
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);
    expect(fixture.incoming.isRead, isTrue);
    expect(read, 1);
    expect(fixture.readRequest, [_chat.id, _me.id]);
    final field = find.byType(TextField);
    final button = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Send message');
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    await tester.enterText(field, 'Thanks!');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Thanks!');
    expect(sent, 0);
    expect(find.text('Message not sent. Tap send to retry.'), findsOneWidget);
    fixture.failSend = false;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(fixture.outgoing?.content, 'Thanks!');
    expect(fixture.outgoing?.receiverId, _friend.id);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(sent, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await bloc.close();
  });
}
