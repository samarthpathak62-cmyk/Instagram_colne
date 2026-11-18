import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/entities/message.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_chats.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_messages.dart';
import 'package:instagram_clone/features/chat/domain/usecases/send_message.dart';
import 'package:instagram_clone/features/chat/domain/usecases/mark_messages_as_read.dart';
import 'package:instagram_clone/features/chat/domain/usecases/subscribe_to_chats.dart';
import 'package:instagram_clone/features/chat/domain/usecases/subscribe_to_messages.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GetChats getChats;
  final GetMessages getMessages;
  final SendMessage sendMessage;
  final MarkMessagesAsRead markMessagesAsRead;
  final SubscribeToChats subscribeToChats;
  final SubscribeToMessages subscribeToMessages;

  ChatBloc({
    required this.getChats,
    required this.getMessages,
    required this.sendMessage,
    required this.markMessagesAsRead,
    required this.subscribeToChats,
    required this.subscribeToMessages,
  }) : super(ChatInitial()) {
    on<LoadChatsEvent>(_onLoadChats);
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSendMessage);
    on<SubscribeToChatsEvent>(_onSubscribeToChats);
    on<SubscribeToMessagesEvent>(_onSubscribeToMessages);
    on<MarkMessagesAsReadEvent>(_onMarkMessagesAsRead);
  }

  Future<void> _onLoadChats(
      LoadChatsEvent event, Emitter<ChatState> emit) async {
    if (_loadingChats) {
      _reloadInbox = true;
      return;
    }
    _loadingChats = true;
    try {
      final version = _inboxVersion;
      if (state is! ChatsLoaded && !event.quiet) emit(ChatsLoading());
      final result = await getChats(GetChatsParams(userId: event.userId));
      if (version != _inboxVersion) return;
      result.fold(
        (failure) {
          if (!event.quiet && state is! ChatsLoaded)
            emit(ChatError(message: failure.message));
        },
        (chats) => emit(ChatsLoaded(chats: chats)),
      );
    } finally {
      _loadingChats = false;
      if (_reloadInbox && !isClosed) {
        _reloadInbox = false;
        add(LoadChatsEvent(userId: event.userId, quiet: state is ChatsLoaded));
      }
    }
  }

  int _inboxVersion = 0;
  bool _loadingChats = false;
  bool _reloadInbox = false;
  bool _markingRead = false;
  bool _loadingMessages = false;

  final _messages = <String, Message>{};
  String? _openChatId;

  void _emitMessages(String chatId, Emitter<ChatState> emit) {
    final messages = _messages.values.toList()
      ..sort((a, b) {
        final order = a.timestamp.compareTo(b.timestamp);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    emit(MessagesLoaded(messages: messages, chatId: chatId));
  }

  void _addMessage(Message message, Emitter<ChatState> emit) {
    if (message.chatId != _openChatId) return;
    if (_messages[message.id]?.isRead != true) _messages[message.id] = message;
    _emitMessages(message.chatId, emit);
  }

  Future<void> _onLoadMessages(
      LoadMessagesEvent event, Emitter<ChatState> emit) async {
    if (_loadingMessages) return;
    _loadingMessages = true;
    try {
      if (_openChatId != event.chatId) _messages.clear();
      _openChatId = event.chatId;
      if (!event.quiet && state is! MessagesLoaded) emit(MessagesLoading());
      final result = await getMessages(GetMessagesParams(chatId: event.chatId));
      result.fold(
        (failure) {
          if (!event.quiet) emit(ChatError(message: failure.message));
        },
        (messages) {
          for (final message in messages) {
            if (_messages[message.id]?.isRead != true)
              _messages[message.id] = message;
          }
          _emitMessages(event.chatId, emit);
        },
      );
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _onSendMessage(
      SendMessageEvent event, Emitter<ChatState> emit) async {
    final result = await sendMessage(SendMessageParams(
      chatId: event.chatId,
      senderId: event.senderId,
      receiverId: event.receiverId,
      content: event.content,
    ));
    result.fold(
      (failure) {
        emit(MessageSendFailed(failure.message));
        _emitMessages(event.chatId, emit);
      },
      (message) {
        emit(MessageSent(message: message));
        _addMessage(message, emit);
      },
    );
  }

  Future<void> _onMarkMessagesAsRead(
      MarkMessagesAsReadEvent event, Emitter<ChatState> emit) async {
    if (_markingRead || _openChatId != event.chatId) return;
    final unread = _messages.values
        .where(
            (message) => message.receiverId == event.userId && !message.isRead)
        .toList();
    if (unread.isEmpty) return;
    _markingRead = true;
    try {
      final result = await markMessagesAsRead(
          MarkMessagesAsReadParams(chatId: event.chatId, userId: event.userId));
      if (_openChatId != event.chatId) return;
      result.fold((_) {}, (updated) {
        if (!updated) return;
        for (final message in unread) {
          _messages[message.id] = message.asRead();
        }
        emit(MessagesMarkedAsRead(chatId: event.chatId));
        _emitMessages(event.chatId, emit);
      });
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _onSubscribeToChats(
      SubscribeToChatsEvent event, Emitter<ChatState> emit) async {
    final result =
        await subscribeToChats(SubscribeToChatsParams(userId: event.userId));
    // Realtime is best effort. A transient socket failure must not clear the
    // inbox already rendered from REST; the foreground poll will catch up.
    await result.fold<Future<void>>(
        (_) async {},
        (stream) => emit.onEach(
              stream,
              onData: (update) => update.fold<void>((_) {}, (chats) {
                _inboxVersion++;
                emit(ChatsLoaded(chats: chats));
              }),
            ));
  }

  Future<void> _onSubscribeToMessages(
      SubscribeToMessagesEvent event, Emitter<ChatState> emit) async {
    final result = await subscribeToMessages(
        SubscribeToMessagesParams(chatId: event.chatId));
    await result.fold<Future<void>>(
      (_) async {},
      (stream) => emit.onEach(stream,
          onData: (update) => update.fold<void>(
              (_) {}, (message) => _addMessage(message, emit))),
    );
  }
}
