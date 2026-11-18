import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:instagram_clone/features/post/presentation/post_links.dart';

Future<void> showSharePost(BuildContext context, String postId) async {
  final auth = context.read<AuthBloc>().state;
  final link = PostLinks.link(postId).toString();
  final direct = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share post', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Send this post to someone on Veyro, or copy a link.'),
              const SizedBox(height: 14),
              SelectableText(link,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy link'),
                  onPressed: () async {
                    try {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!context.mounted) return;
                      Navigator.pop(context, false);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('Select the link to copy it manually.')));
                    }
                  },
                ),
                if (auth is Authenticated)
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send in message'),
                  ),
              ]),
            ]),
      ),
    ),
  );
  if (!context.mounted) return;
  if (direct == false) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post link copied')));
  } else if (direct == true && auth is Authenticated) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatsListScreen(
              currentUser: auth.user,
              draft: PostLinks.link(postId, portable: true).toString(),
            )));
  }
}
