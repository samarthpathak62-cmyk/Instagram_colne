import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_or_create_chat.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/explore/domain/usecases/search_users.dart';

class NewMessageScreen extends StatefulWidget {
  final User currentUser;
  final String? draft;

  const NewMessageScreen({super.key, required this.currentUser, this.draft});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  bool _searching = false;
  String? _opening;
  String? _error;
  List<User> _matches = const [];

  void _queueSearch(String value) {
    _debounce?.cancel();
    final query = value.trim().replaceFirst(RegExp(r'^@'), '');
    final generation = ++_generation;
    setState(() {
      _matches = const [];
      _error = null;
      _searching = query.isNotEmpty;
    });
    if (query.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final result = await sl<SearchUsers>()(SearchUsersParams(query: query));
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        result.fold((failure) => _error = failure.message, (users) {
          _matches =
              users.where((user) => user.id != widget.currentUser.id).toList();
        });
      });
    });
  }

  Future<void> _openChat(User other) async {
    if (_opening != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _opening = other.id);
    final result = await sl<GetOrCreateChat>()(GetOrCreateChatParams(
        currentUserId: widget.currentUser.id, otherUserId: other.id));
    if (!mounted) return;
    setState(() => _opening = null);
    await result.fold<Future<void>>((failure) async {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }, (chat) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
                create: (_) => sl<ChatBloc>(),
                child: ChatDetailScreen(
                    chat: chat,
                    currentUser: widget.currentUser,
                    initialMessage: widget.draft),
              )));
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                Text(widget.draft == null ? 'New message' : 'Send post to…')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        maxLength: 50,
                        onChanged: _queueSearch,
                        decoration: const InputDecoration(
                            labelText: 'Search by username',
                            prefixIcon: Icon(Icons.search_rounded),
                            counterText: ''),
                      )),
                  Expanded(
                      child: _searching
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(
                                  child: TextButton(
                                      onPressed: () =>
                                          _queueSearch(_controller.text),
                                      child: const Text(
                                          'Could not search. Retry')))
                              : _matches.isEmpty
                                  ? Center(
                                      child: Text(
                                          _controller.text.trim().isEmpty
                                              ? 'Find a person to message.'
                                              : 'No people found.'))
                                  : ListView.builder(
                                      itemCount: _matches.length,
                                      itemBuilder: (context, index) {
                                        final user = _matches[index];
                                        return ListTile(
                                          onTap: _opening != null
                                              ? null
                                              : () => _openChat(user),
                                          leading: UserAvatar(
                                              imageUrl: user.profilePictureUrl),
                                          title: Text(
                                              '@${user.username ?? 'veyro_user'}'),
                                          trailing: _opening == user.id
                                              ? const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : const Icon(
                                                  Icons.chevron_right_rounded),
                                        );
                                      })),
                ]))),
      );
}
