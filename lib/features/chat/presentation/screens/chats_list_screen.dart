import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/generated/app_localizations.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:instagram_clone/features/chat/presentation/screens/new_message_screen.dart';

class ChatsListScreen extends StatefulWidget {
  final User currentUser;

  const ChatsListScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToChats();
  }

  void _loadChats() {
    context.read<ChatBloc>().add(LoadChatsEvent(userId: widget.currentUser.id));
  }

  void _subscribeToChats() {
    context
        .read<ChatBloc>()
        .add(SubscribeToChatsEvent(userId: widget.currentUser.id));
  }

  Future<void> _newMessage() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => NewMessageScreen(currentUser: widget.currentUser)));
    if (mounted) _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.messages ?? 'Messages'),
        actions: [
          IconButton(
              tooltip: 'Refresh messages',
              onPressed: _loadChats,
              icon: const Icon(Icons.refresh_rounded)),
          IconButton(
              tooltip: 'New message',
              onPressed: _newMessage,
              icon: const Icon(Icons.edit_square)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: BlocConsumer<ChatBloc, ChatState>(
            listener: (context, state) {
              if (state is ChatError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              }
            },
            builder: (context, state) {
              if (state is ChatsLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ChatsLoaded) {
                return _buildChatsList(state.chats, l10n);
              } else if (state is ChatError) {
                return Center(
                    child: TextButton(
                        onPressed: _loadChats,
                        child: const Text('Could not load chats. Retry')));
              } else {
                return _buildChatsList([], l10n);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChatsList(List<Chat> chats, AppLocalizations? l10n) {
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 31,
              backgroundColor: context.veyroColors.primaryContainer,
              foregroundColor: context.veyroColors.onPrimaryContainer,
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 27),
            ),
            const SizedBox(height: 14),
            Text(l10n?.noMessages ?? 'No messages',
                style: context.veyroText.titleMedium),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _newMessage,
                child: const Text('Start a conversation')),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final otherUser = chat.otherUser;
        if (otherUser == null) {
          return ListTile(
            leading:
                Icon(Icons.error_outline, color: context.veyroColors.error),
            title: const Text('Unknown user'),
            subtitle: const Text('User data is missing'),
          );
        }
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: otherUser.profileImageUrl != null
                ? NetworkImage(otherUser.profileImageUrl!)
                : null,
            child: otherUser.profileImageUrl == null
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(otherUser.username ?? 'Unknown User'),
          subtitle: Text(
            chat.hasUnreadMessages ? 'New messages' : 'No new messages',
            style: TextStyle(
              fontWeight:
                  chat.hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: chat.hasUnreadMessages
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.veyroColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider<ChatBloc>(
                  create: (_) => di.sl<ChatBloc>(),
                  child: ChatDetailScreen(
                      chat: chat, currentUser: widget.currentUser),
                ),
              ),
            );
            if (mounted) _loadChats();
          },
        );
      },
    );
  }
}
