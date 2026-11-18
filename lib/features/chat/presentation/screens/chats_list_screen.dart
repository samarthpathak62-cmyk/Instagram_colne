import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_or_create_chat.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
import 'package:instagram_clone/features/explore/domain/usecases/search_users.dart';
import 'package:instagram_clone/features/post/presentation/post_links.dart';
import 'package:instagram_clone/generated/app_localizations.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatsListScreen extends StatefulWidget {
  final User currentUser;
  final String? draft;

  const ChatsListScreen({super.key, required this.currentUser, this.draft});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  int _generation = 0;
  String _query = '';
  String? _opening;
  List<User> _people = const [];
  bool _searching = false;
  bool _searchFailed = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _loadChats() => context
      .read<ChatBloc>()
      .add(LoadChatsEvent(userId: widget.currentUser.id));

  void _queueSearch(String value) {
    _debounce?.cancel();
    final query = value.trim().replaceFirst(RegExp(r'^@'), '').trim();
    final generation = ++_generation;
    setState(() {
      _query = query.toLowerCase();
      _people = const [];
      _searchFailed = false;
      _searching = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final result = await sl<SearchUsers>()(SearchUsersParams(query: query));
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        result.fold(
            (_) => _searchFailed = true,
            (users) => _people = users
                .where((user) => user.id != widget.currentUser.id)
                .toList());
      });
    });
  }

  Future<void> _open({Chat? chat, User? person}) async {
    if (_opening != null) return;
    _searchFocus.unfocus();
    setState(() => _opening = chat?.id ?? person!.id);
    try {
      if (chat == null) {
        final result = await sl<GetOrCreateChat>()(GetOrCreateChatParams(
            currentUserId: widget.currentUser.id, otherUserId: person!.id));
        if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
        chat = result.fold((_) => null, (value) => value);
        if (chat == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Couldn’t open this conversation. Try again.')));
          return;
        }
      }
      final sent = await ChatDetailScreen.open(context,
          chat: chat,
          currentUser: widget.currentUser,
          initialMessage: widget.draft);
      if (!mounted) return;
      if (widget.draft != null && sent) {
        Navigator.of(context).pop();
      } else {
        _loadChats();
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  bool _matches(Chat chat) =>
      _query.isEmpty ||
      (chat.otherUser?.username?.toLowerCase().contains(_query) ?? false) ||
      (chat.otherUser?.name?.toLowerCase().contains(_query) ?? false);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatBloc>().state;
    final chats = state is ChatsLoaded ? state.chats : const <Chat>[];
    final visible = chats
        .where((chat) =>
            (chat.lastMessageContent != null || chat.hasUnreadMessages) &&
            _matches(chat))
        .toList();
    final visibleIds = visible.map((chat) => chat.otherUser?.id).toSet();
    final matches =
        _people.where((person) => !visibleIds.contains(person.id)).toList();
    final share = widget.draft != null;
    final colors = context.veyroColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(share
            ? 'Send post to…'
            : AppLocalizations.of(context)?.messages ?? 'Messages'),
        actions: [
          if (!share)
            IconButton(
                tooltip: 'New message',
                onPressed: () => _searchFocus.requestFocus(),
                icon: const Icon(Icons.edit_square)),
        ],
      ),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onChanged: _queueSearch,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'Search by username',
                labelText: 'Search by username',
                counterText: '',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          _queueSearch('');
                          _searchFocus.requestFocus();
                        }),
              ),
            ),
          ),
          Expanded(
              child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (visible.isNotEmpty) ...[
                SliverToBoxAdapter(
                    child: _heading(
                        share && _query.isEmpty ? 'Recent' : 'Conversations')),
                SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) => _chatRow(visible[i])),
              ],
              if (_query.isNotEmpty) ...[
                if (matches.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _heading('People')),
                  SliverList.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) => _personRow(matches[i])),
                ],
                if (_searching)
                  const SliverToBoxAdapter(
                      child: LinearProgressIndicator(minHeight: 2)),
                if (_searchFailed)
                  SliverToBoxAdapter(
                      child: Center(
                          child: TextButton(
                              onPressed: () => _queueSearch(_search.text),
                              child: const Text('Couldn’t search. Retry')))),
                if (visible.isEmpty &&
                    matches.isEmpty &&
                    !_searching &&
                    !_searchFailed)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: VeyroEmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No people found',
                          description:
                              'Check the username or try a shorter search.')),
              ] else if (visible.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: switch (state) {
                      ChatsLoading() ||
                      ChatInitial() =>
                        const Center(child: CircularProgressIndicator()),
                      ChatError() => VeyroEmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: 'Couldn’t load messages',
                          description:
                              'Check your connection or search for a person.',
                          action: TextButton(
                              onPressed: _loadChats,
                              child: const Text('Retry'))),
                      _ => VeyroEmptyState(
                          icon: Icons.send_outlined,
                          title: share
                              ? 'Choose who to send to'
                              : 'Start a conversation',
                          description: share
                              ? 'Search for the person you want to share this post with.'
                              : 'Search for someone to say hello or share a post.',
                          action: FilledButton.tonalIcon(
                              onPressed: () => _searchFocus.requestFocus(),
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Find someone'))),
                    }),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
            ],
          )),
          SafeArea(
              top: false,
              child: Divider(height: 1, color: colors.outlineVariant)),
        ]),
      )),
    );
  }

  Widget _heading(String label) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
      child: Text(label, style: context.veyroText.titleMedium));

  Widget _chatRow(Chat chat) {
    final person = chat.otherUser;
    final name = person?.name ?? person?.username ?? 'Veyro user';
    final unread = chat.hasUnreadMessages;
    final colors = context.veyroColors;
    final content = chat.lastMessageContent;
    final subtitle = content == null
        ? 'New message'
        : PostLinks.inMessage(content) == null
            ? content
            : 'Shared a post';
    return ListTile(
      key: ValueKey(chat.id),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 5, 16, 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: unread ? colors.surfaceContainer : null,
      leading: ExcludeSemantics(
          child: UserAvatar(
              name: name, imageUrl: person?.profileImageUrl, radius: 23)),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.veyroText.titleSmall?.copyWith(
              fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.veyroText.bodySmall?.copyWith(
              color: unread ? colors.onSurface : colors.onSurfaceVariant,
              fontWeight: unread ? FontWeight.w700 : FontWeight.normal)),
      trailing: _opening == chat.id
          ? _progress()
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Text(timeago.format(chat.lastMessageTime, locale: 'en_short'),
                  style: context.veyroText.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
              if (unread) ...[
                const SizedBox(width: 8),
                Semantics(
                    label: 'Unread',
                    child: Icon(Icons.circle, size: 8, color: colors.primary)),
              ],
            ]),
      onTap: _opening == null ? () => _open(chat: chat) : null,
    );
  }

  Widget _personRow(User user) => ListTile(
        key: ValueKey(user.id),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 3, 16, 3),
        leading: ExcludeSemantics(
            child: UserAvatar(
                imageUrl: user.profilePictureUrl,
                name: user.name ?? user.username,
                radius: 22)),
        title: Text(user.name ?? user.username ?? 'Veyro user',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: user.username == null
            ? null
            : Text('@${user.username}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _opening == user.id
            ? _progress()
            : const Icon(Icons.chevron_right_rounded),
        onTap: _opening == null ? () => _open(person: user) : null,
      );

  Widget _progress() => const SizedBox.square(
      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
