import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';
import 'package:instagram_clone/features/post/presentation/screens/share_post_sheet.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_actions.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

enum _PostMenu { open, share, edit, delete }

class PostHeader extends StatelessWidget {
  final Post post;
  final bool showOpenPost;
  final bool canModerate;

  const PostHeader(
      {super.key,
      required this.post,
      this.showOpenPost = true,
      this.canModerate = false});

  @override
  Widget build(BuildContext context) {
    final actions = context.read<PostInteractionsCubit>();
    final editing = context.select(
        (PostInteractionsCubit cubit) => cubit.forPost(post.id).editing);
    final canManage = actions.userId == post.authorId;
    final username = post.user?.username ?? 'veyro_user';
    final name = post.user?.name?.trim();
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsetsDirectional.only(start: 13, end: 6),
      leading: UserAvatar(
          imageUrl: post.user?.profilePictureUrl,
          name: name ?? username,
          radius: 19),
      title: Text(name?.isNotEmpty == true ? name! : '@$username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      subtitle: Text(
          '${name?.isNotEmpty == true ? '@$username · ' : ''}${timeago.format(post.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ProfileScreen.withProviders(post.authorId))),
      trailing: PopupMenuButton<_PostMenu>(
        tooltip: 'Post options',
        enabled: !editing,
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (option) async {
          switch (option) {
            case _PostMenu.open:
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PostDetailScreen(postId: post.id)));
            case _PostMenu.share:
              await showSharePost(context, post.id);
            case _PostMenu.edit:
              final value = await showDialog<String>(
                  context: context,
                  builder: (_) => _EditPostDialog(
                      post: post,
                      description: actions.forPost(post.id).text(post)));
              if (value != null && context.mounted)
                await showPostActionError(context, actions.edit(post, value));
            case _PostMenu.delete:
              final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: Text(canManage
                            ? 'Delete this post?'
                            : 'Remove this group post?'),
                        content: const Text(
                            'This also removes its comments, reactions and saves.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete post')),
                        ],
                      ));
              if (confirmed == true && context.mounted)
                await showPostActionError(
                    context, actions.delete(post, asGroupOwner: canModerate));
          }
        },
        itemBuilder: (_) => [
          if (showOpenPost)
            const PopupMenuItem(
                value: _PostMenu.open, child: Text('Open post')),
          const PopupMenuItem(
              value: _PostMenu.share, child: Text('Share post')),
          if (canManage && post.shareKind != PostShareKind.repost)
            const PopupMenuItem(
                value: _PostMenu.edit, child: Text('Edit post')),
          if (canManage || canModerate)
            PopupMenuItem(
                value: _PostMenu.delete,
                child: Text(canManage ? 'Delete post' : 'Remove from group')),
        ],
      ),
    );
  }
}

class _EditPostDialog extends StatefulWidget {
  final Post post;
  final String description;

  const _EditPostDialog({required this.post, required this.description});

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final _text = TextEditingController(text: widget.description);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Edit post'),
        content: TextField(
          autofocus: true,
          controller: _text,
          minLines: 2,
          maxLines: 6,
          maxLength: Post.maxDescriptionLength,
          decoration: const InputDecoration(labelText: 'Post text'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (context, value, _) => FilledButton(
              onPressed:
                  widget.post.type == PostType.text && value.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, value.text),
              child: const Text('Save changes'),
            ),
          ),
        ],
      );
}
