import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/generated/app_localizations.dart';
import 'package:instagram_clone/features/post/presentation/post_links.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/entities/message.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;
  final User currentUser;
  final String? initialMessage;

  const ChatDetailScreen({
    Key? key,
    required this.chat,
    required this.currentUser,
    this.initialMessage,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final _messageController =
      TextEditingController(text: widget.initialMessage);
  bool _sending = false;
  final ScrollController _scrollController = ScrollController();
  String? _lastMessageId;
  List<Message>? _visibleMessages;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    context.read<ChatBloc>().add(LoadMessagesEvent(chatId: widget.chat.id));
  }

  void _subscribeToMessages() {
    context
        .read<ChatBloc>()
        .add(SubscribeToMessagesEvent(chatId: widget.chat.id));
  }

  void _markMessagesAsRead() {
    context.read<ChatBloc>().add(MarkMessagesAsReadEvent(
          chatId: widget.chat.id,
          userId: widget.currentUser.id,
        ));
  }

  void _sendMessage() {
    if (_sending || _messageController.text.trim().isEmpty) return;
    setState(() => _sending = true);

    context.read<ChatBloc>().add(SendMessageEvent(
          chatId: widget.chat.id,
          senderId: widget.currentUser.id,
          receiverId: widget.chat.otherUser?.id ??
              (widget.chat.user1Id == widget.currentUser.id
                  ? widget.chat.user2Id
                  : widget.chat.user1Id),
          content: _messageController.text.trim(),
        ));
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.otherUser?.username ?? 'Chat'),
        actions: [
          IconButton(
              tooltip: 'Refresh messages',
              onPressed: _loadMessages,
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: BlocConsumer<ChatBloc, ChatState>(
                  listener: (context, state) {
                    if (state is MessageSent) {
                      _messageController.clear();
                      setState(() => _sending = false);
                    } else if (state is MessageSendFailed) {
                      setState(() => _sending = false);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(state.message)));
                    } else if (state is MessagesLoaded) {
                      _visibleMessages = state.messages;
                      if (state.messages.isEmpty) return;
                      final last = state.messages.last;
                      if (last.id == _lastMessageId) return;
                      _lastMessageId = last.id;
                      if (last.receiverId == widget.currentUser.id &&
                          !last.isRead) {
                        _markMessagesAsRead();
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _scrollToBottom();
                      });
                    }
                  },
                  buildWhen: (_, state) =>
                      state is MessagesLoading ||
                      state is MessagesLoaded ||
                      state is ChatError,
                  builder: (context, state) {
                    if (state is MessagesLoaded)
                      return _buildMessagesList(state.messages);
                    if (_visibleMessages != null)
                      return _buildMessagesList(_visibleMessages!);
                    if (state is ChatError) {
                      return Center(
                          child: TextButton(
                              onPressed: _loadMessages,
                              child: const Text(
                                  'Could not load messages. Retry')));
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
              _buildMessageInput(l10n?.typeMessage ?? 'Type a message'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList(List<Message> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)?.noMessages ?? 'No messages'),
      );
    }

    final colors = context.veyroColors;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isCurrentUser = message.senderId == widget.currentUser.id;
        final postId = PostLinks.inMessage(message.content);

        return Align(
          alignment: isCurrentUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: EdgeInsetsDirectional.only(
              top: 4,
              bottom: 4,
              start: isCurrentUser ? 30 : 4,
              end: isCurrentUser ? 4 : 30,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (postId != null)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PostDetailScreen(postId: postId))),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('View shared post'),
                  )
                else
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                    ),
                  ),
                const SizedBox(height: 4.0),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: isCurrentUser
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontSize: 10.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(String hint) {
    final colors = context.veyroColors;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_sending,
                decoration: InputDecoration(hintText: hint),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send message',
              icon: const Icon(Icons.send_rounded, size: 20),
              onPressed: _sending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    dateTime = dateTime.toLocal();
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
