import 'package:flutter/material.dart';
import 'package:instagram_clone/features/groups/presentation/group_detail_screen.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';

class GroupPostOrigin extends StatelessWidget {
  final Post post;

  const GroupPostOrigin({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final groupId = post.groupId;
    if (groupId == null || post.groupName == null)
      return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => GroupDetailScreen(groupId: groupId),
        )),
        icon: const Icon(Icons.groups_outlined, size: 20),
        label:
            Text(post.groupName!, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
