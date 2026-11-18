import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/generated/app_localizations.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToChats();
    // Push updates are preferred; periodically refresh while visible so direct
    // messages still arrive when a Realtime connection is unavailable.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (mounted &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          ModalRoute.isCurrentOf(context) == true) {
        _loadChats(quiet: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadChats({bool quiet = false}) {
    context
        .read<ChatBloc>()
        .add(LoadChatsEvent(userId: widget.currentUser.id, quiet: quiet));
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
      return VeyroEmptyState(
        icon: Icons.send_outlined,
        title: l10n?.noMessages ?? 'No messages',
        description: 'Say hello or share a post with someone on Veyro.',
        action: FilledButton.icon(
            onPressed: _newMessage,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Start a conversation')),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 18),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: chat.hasUnreadMessages
              ? context.veyroColors.primaryContainer
              : null,
          leading: UserAvatar(
              imageUrl: otherUser.profileImageUrl,
              name: otherUser.name ?? otherUser.username,
              radius: 22),
          title: Text(otherUser.username ?? 'Veyro user',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.veyroText.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
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
