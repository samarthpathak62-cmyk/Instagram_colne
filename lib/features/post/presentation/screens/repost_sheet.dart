import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/shared_post_preview.dart';

Future<void> showRepostOptions(BuildContext context, Post post) async {
  final target = post.shareTargetId;
  if (target == null) return;
  final actions = context.read<PostInteractionsCubit>();
  final feed = context.read<FeedCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final result = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) =>
        _RepostSheet(target: target, post: post.sharePreview, actions: actions),
  );
  if (result == null) return;
  if (messenger.mounted)
    messenger.showSnackBar(SnackBar(content: Text(result)));
  if (!feed.isClosed) await feed.refresh();
}

class _RepostSheet extends StatefulWidget {
  final String target;
  final Post? post;
  final PostInteractionsCubit actions;

  const _RepostSheet(
      {required this.target, required this.post, required this.actions});

  @override
  State<_RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends State<_RepostSheet> {
  final _text = TextEditingController();
  Post? _repost;
  bool _loading = true;
  bool _quoting = false;
  bool _saving = false;
  String? _lookupError;
  String? _writeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _lookupError = null;
    });
    final actions = widget.actions;
    final result =
        await actions.repository.findRepost(widget.target, actions.userId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((failure) => _lookupError = failure.message,
          (value) => _repost = value);
    });
  }

  Future<void> _submit({bool quote = false}) async {
    if (_saving || (quote && _text.text.trim().isEmpty)) return;
    final existing = _repost;
    final removing = !quote && existing != null;
    final actions = widget.actions;
    setState(() {
      _saving = true;
      _writeError = null;
    });
    final String? error;
    if (!quote && existing != null) {
      error = await actions.delete(existing);
    } else {
      final result = await actions.repository.createShare(
          widget.target, actions.userId,
          quote: quote ? _text.text.trim() : null);
      error = result.fold((failure) => failure.message, (_) => null);
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _writeError = error;
    });
    if (error == null)
      Navigator.of(context).pop(quote
          ? 'Quote published'
          : removing
              ? 'Repost removed'
              : 'Reposted');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(_quoting ? 'Quote post' : 'Share to Veyro',
                    style: theme.textTheme.titleLarge)),
            IconButton(
                tooltip: 'Close repost options',
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 6),
          SharedPostPreview(post: widget.post, interactive: false),
          const SizedBox(height: 14),
          if (_quoting) ...[
            TextField(
              controller: _text,
              enabled: !_saving,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: Post.maxDescriptionLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Your take',
                  hintText: 'Add a thought before sharing…'),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (_, value, __) => FilledButton.icon(
                onPressed: _saving || value.text.trim().isEmpty
                    ? null
                    : () => _submit(quote: true),
                icon: const Icon(Icons.format_quote_rounded),
                label: const Text('Publish quote'),
              ),
            ),
          ] else ...[
            if (_loading)
              const LinearProgressIndicator()
            else if (_lookupError != null)
              OutlinedButton(
                  onPressed: _load, child: const Text('Retry repost check'))
            else
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: Icon(_repost == null
                    ? Icons.repeat_rounded
                    : Icons.undo_rounded),
                label: Text(_repost == null ? 'Repost now' : 'Undo repost'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _quoting = true;
                        _writeError = null;
                      }),
              icon: const Icon(Icons.format_quote_outlined),
              label: const Text('Quote post'),
            ),
          ],
          if (_writeError != null) ...[
            const SizedBox(height: 8),
            Text(_writeError!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_saving) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ]),
      ),
    );
  }
}
