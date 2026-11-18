import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/entities/chat.dart';
import 'package:instagram_clone/features/chat/domain/entities/message.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
import 'package:instagram_clone/features/post/presentation/post_links.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';
import 'package:instagram_clone/generated/app_localizations.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;
  final User currentUser;
  final String? initialMessage;
  final VoidCallback? onMessageSent;
  final VoidCallback? onRead;

  const ChatDetailScreen(
      {super.key,
      required this.chat,
      required this.currentUser,
      this.initialMessage,
      this.onMessageSent,
      this.onRead});

  static Future<bool> open(BuildContext context,
      {required Chat chat,
      required User currentUser,
      String? initialMessage}) async {
    final inbox = context.read<ChatBloc?>();
    var sent = false;
    void refreshInbox() {
      if (inbox != null && !inbox.isClosed) {
        inbox.add(LoadChatsEvent(userId: currentUser.id, quiet: true));
      }
    }

    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BlocProvider<ChatBloc>(
              create: (_) => sl<ChatBloc>(),
              child: ChatDetailScreen(
                  chat: chat,
                  currentUser: currentUser,
                  initialMessage: initialMessage,
                  onRead: refreshInbox,
                  onMessageSent: () {
                    sent = true;
                    refreshInbox();
                  }),
            )));
    return sent;
  }

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late String? _attachment =
      PostLinks.inMessage(widget.initialMessage ?? '') != null
          ? widget.initialMessage
          : null;
  late final _text = TextEditingController(
      text: _attachment == null ? widget.initialMessage : null);
  final _scroll = ScrollController();
  late final Timer _refreshTimer;
  late final AppLifecycleListener _lifecycle;
  bool _sending = false;
  bool _current = false;
  List<Message>? _visibleMessages;

  String get _otherId => widget.chat.user1Id == widget.currentUser.id
      ? widget.chat.user2Id
      : widget.chat.user1Id;
  String get _name =>
      widget.chat.otherUser?.name ??
      widget.chat.otherUser?.username ??
      'Conversation';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    context
        .read<ChatBloc>()
        .add(SubscribeToMessagesEvent(chatId: widget.chat.id));
    _lifecycle = AppLifecycleListener(onResume: _refreshVisible);
    // Keep reading the conversation working even without a Realtime socket.
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _refreshVisible());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_current && _visibleMessages != null) {
      _current = true;
      _refreshVisible();
    }
    _current = current;
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _lifecycle.dispose();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _visible {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return _current &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  void _refreshVisible() {
    if (!mounted || !_visible) return;
    _loadMessages(quiet: _visibleMessages != null);
    _markReadIfVisible();
  }

  void _loadMessages({bool quiet = false}) => context
      .read<ChatBloc>()
      .add(LoadMessagesEvent(chatId: widget.chat.id, quiet: quiet));

  void _markReadIfVisible() {
    if (!_visible ||
        !(_visibleMessages?.any((message) =>
                message.receiverId == widget.currentUser.id &&
                !message.isRead) ??
            false)) return;
    context.read<ChatBloc>().add(MarkMessagesAsReadEvent(
        chatId: widget.chat.id, userId: widget.currentUser.id));
  }

  void _send() {
    final content = _attachment ?? _text.text.trim();
    if (_sending || content.isEmpty) return;
    setState(() => _sending = true);
    context.read<ChatBloc>().add(SendMessageEvent(
        chatId: widget.chat.id,
        senderId: widget.currentUser.id,
        receiverId: _otherId,
        content: content));
  }

  void _handleState(BuildContext context, ChatState state) {
    if (state is MessageSent) {
      setState(() {
        _attachment = null;
        _sending = false;
        _text.clear();
      });
      widget.onMessageSent?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    } else if (state is MessageSendFailed) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Message not sent. Tap send to retry.')));
    } else if (state is MessagesLoaded) {
      _visibleMessages = state.messages;
      _markReadIfVisible();
    } else if (state is MessagesMarkedAsRead) {
      widget.onRead?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = widget.chat.otherUser;
    return Scaffold(
      appBar: AppBar(
          title: Tooltip(
            message: 'View profile',
            excludeFromSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen.withProviders(_otherId))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ExcludeSemantics(
                    child: UserAvatar(
                        imageUrl: user?.profileImageUrl,
                        name: _name,
                        radius: 18)),
                const SizedBox(width: 10),
                Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(_name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.veyroText.titleSmall),
                      if (user?.username != null)
                        Text('@${user!.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.veyroText.bodySmall),
                    ])),
              ]),
            ),
          ),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1), child: Divider(height: 1))),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(children: [
          Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
            listener: _handleState,
            buildWhen: (_, state) =>
                state is MessagesLoading ||
                state is MessagesLoaded ||
                state is ChatError,
            builder: (context, state) {
              final messages =
                  state is MessagesLoaded ? state.messages : _visibleMessages;
              if (messages != null) return _history(messages);
              if (state is ChatError)
                return VeyroEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Couldn’t load this chat',
                    description: 'Check your connection and try again.',
                    action: FilledButton.tonal(
                        onPressed: _loadMessages, child: const Text('Retry')));
              return const Center(child: CircularProgressIndicator());
            },
          )),
          _composer(l10n?.typeMessage ?? 'Type a message'),
        ]),
      )),
    );
  }

  Widget _history(List<Message> messages) {
    if (messages.isEmpty)
      return VeyroEmptyState(
          icon: Icons.waving_hand_outlined,
          title: 'Say hello',
          description: 'Send the first message to $_name.');
    final colors = context.veyroColors;
    final localization = MaterialLocalizations.of(context);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final i = messages.length - 1 - index;
        final message = messages[i];
        final ours = message.senderId == widget.currentUser.id;
        final time = message.timestamp.toLocal();
        final dateStart = i == 0 ||
            !DateUtils.isSameDay(time, messages[i - 1].timestamp.toLocal());
        final newGroup = dateStart || !_sameRun(messages[i - 1], message);
        final lastInGroup =
            i == messages.length - 1 || !_sameRun(message, messages[i + 1]);
        final postId = PostLinks.inMessage(message.content);
        return Column(key: ValueKey(message.id), children: [
          if (dateStart)
            Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 9),
                child: Text(localization.formatMediumDate(time),
                    textAlign: TextAlign.center,
                    style: context.veyroText.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant))),
          Row(
              mainAxisAlignment:
                  ours ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!ours) ...[
                  if (lastInGroup)
                    ExcludeSemantics(
                        child: UserAvatar(
                            imageUrl: widget.chat.otherUser?.profileImageUrl,
                            name: _name,
                            radius: 13))
                  else
                    const SizedBox(width: 26),
                  const SizedBox(width: 7),
                ] else
                  const SizedBox(width: 35),
                Flexible(
                    child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  margin: EdgeInsetsDirectional.only(
                      top: newGroup ? 8 : 2, end: ours ? 0 : 23),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                      color: ours
                          ? colors.primaryContainer
                          : colors.surfaceContainerHigh,
                      borderRadius: BorderRadiusDirectional.only(
                          topStart: const Radius.circular(18),
                          topEnd: const Radius.circular(18),
                          bottomStart:
                              Radius.circular(ours || !lastInGroup ? 18 : 5),
                          bottomEnd:
                              Radius.circular(!ours || !lastInGroup ? 18 : 5))),
                  child: postId == null
                      ? Text(message.content,
                          style: context.veyroText.bodyMedium?.copyWith(
                              color: ours
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface))
                      : TextButton.icon(
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('View shared post'),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PostDetailScreen(postId: postId)))),
                )),
              ]),
          if (lastInGroup)
            Align(
                alignment: ours
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Padding(
                    padding: EdgeInsetsDirectional.only(
                        start: ours ? 0 : 36, top: 3, bottom: 2),
                    child: Text(TimeOfDay.fromDateTime(time).format(context),
                        style: context.veyroText.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant)))),
        ]);
      },
    );
  }

  bool _sameRun(Message first, Message next) =>
      first.senderId == next.senderId &&
      DateUtils.isSameDay(
          first.timestamp.toLocal(), next.timestamp.toLocal()) &&
      next.timestamp.difference(first.timestamp).inMinutes < 5;

  Widget _composer(String hint) {
    final colors = context.veyroColors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: _attachment == null
                  ? TextField(
                      controller: _text,
                      readOnly: _sending,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                          hintText: hint,
                          filled: true,
                          fillColor: colors.surfaceContainerHigh,
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(
                              16, 10, 16, 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: colors.primary))))
                  : Material(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(17),
                      child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.link_rounded),
                          title: const Text('Post attached'),
                          trailing: IconButton(
                              tooltip: 'Remove shared post',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _sending
                                  ? null
                                  : () =>
                                      setState(() => _attachment = null))))),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (context, value, _) => IconButton.filled(
                    tooltip: _sending ? 'Sending message' : 'Send message',
                    onPressed: _sending ||
                            (_attachment == null && value.text.trim().isEmpty)
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 19),
                  )),
        ]),
      ),
    );
  }
}
