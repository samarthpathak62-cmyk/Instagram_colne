import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/post/domain/entities/post_comment.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

Future<void> showPostComments(BuildContext context, String postId) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: FractionallySizedBox(
            heightFactor: .78, child: _CommentsSheet(postId: postId)),
      ),
    );

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _comments = <PostComment>[];
  late final PostInteractionsCubit _actions;
  int _total = 0;
  bool _loading = false;
  bool _writing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _actions = context.read<PostInteractionsCubit>();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || _writing) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _actions.repository
        .getComments(widget.postId, offset: more ? _comments.length : 0);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((failure) => _error = failure.message, (page) {
        if (!more) _comments.clear();
        final seen = _comments.map((comment) => comment.id).toSet();
        _comments
            .addAll(page.comments.where((comment) => seen.add(comment.id)));
        _total = page.total;
      });
    });
    if (_error == null) _actions.updateCommentCount(widget.postId, _total);
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (_writing || _loading || value.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _writing = true);
    final result = await _actions.repository
        .addComment(widget.postId, _actions.userId, value);
    if (!mounted) return;
    setState(() => _writing = false);
    result.fold((failure) => _showError(failure.message), (comment) {
      _text.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _load();
    });
  }

  Future<void> _remove(PostComment comment) async {
    final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete comment?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete')),
              ],
            ));
    if (!mounted || remove != true || _loading || _writing) return;
    setState(() => _writing = true);
    final result =
        await _actions.repository.deleteComment(comment.id, _actions.userId);
    if (!mounted) return;
    setState(() => _writing = false);
    result.fold((failure) => _showError(failure.message), (_) {
      setState(() => _comments.removeWhere((item) => item.id == comment.id));
      _load();
    });
  }

  void _showError(String error) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(error)));

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Column(
          children: [
            Row(children: [
              const SizedBox(width: 20),
              Expanded(
                  child: Text('Comments',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Refresh comments',
                  onPressed: _loading || _writing ? null : () => _load(),
                  icon: const Icon(Icons.refresh_rounded)),
              IconButton(
                  tooltip: 'Close comments',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
              const SizedBox(width: 6),
            ]),
            const Divider(height: 1),
            Expanded(
              child: _comments.isEmpty && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 9, 8, 14),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (_comments.isEmpty && _error == null)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'No comments yet. Start the conversation!',
                                    textAlign: TextAlign.center)),
                          for (final comment in _comments)
                            _comment(context, comment),
                          if (_loading) const LinearProgressIndicator(),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(children: [
                                  Text(_error!, textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: () => _load(),
                                      child: const Text('Retry comments')),
                                ])),
                          if (!_loading &&
                              _error == null &&
                              _comments.length < _total)
                            TextButton(
                                onPressed:
                                    _writing ? null : () => _load(more: true),
                                child: const Text('Load older comments')),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: TextField(
                  controller: _text,
                  enabled: !_writing,
                  maxLength: CommentPage.maxLength,
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'Write a comment…', counterText: ''),
                )),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _text,
                  builder: (context, value, _) => IconButton.filled(
                    tooltip: 'Send comment',
                    onPressed: _writing || _loading || value.text.trim().isEmpty
                        ? null
                        : _send,
                    icon: _writing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ]),
            ),
          ],
        ),
      );

  Widget _comment(BuildContext context, PostComment comment) => ListTile(
        key: ValueKey(comment.id),
        leading: UserAvatar(imageUrl: comment.author?.profilePictureUrl),
        title: Text('@${comment.author?.username ?? 'veyro_user'}',
            style: Theme.of(context).textTheme.labelLarge),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(comment.content, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 3),
          Text(timeago.format(comment.createdAt),
              style: Theme.of(context).textTheme.labelSmall),
        ]),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ProfileScreen.withProviders(comment.userId))),
        trailing: comment.userId == _actions.userId
            ? IconButton(
                tooltip: 'Delete comment',
                onPressed: _writing || _loading ? null : () => _remove(comment),
                icon: const Icon(Icons.delete_outline_rounded, size: 20))
            : null,
      );
}
