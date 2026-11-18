import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/post_detail_screen.dart';

/// Deliberately shallow: a quote of a quote never nests a second card.
class SharedPostPreview extends StatelessWidget {
  final Post? post;
  final bool interactive;

  const SharedPostPreview(
      {super.key, required this.post, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final source = post;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = source == null
        ? null
        : context
            .select((PostInteractionsCubit cubit) => cubit.forPost(source.id));
    final original = state?.deleted == true ? null : source;
    final name =
        original?.user?.name ?? original?.user?.username ?? 'Veyro member';
    final text = original == null ? '' : state?.text(original) ?? '';
    final media = original?.mediaUrls.firstOrNull;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: original != null && interactive
            ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PostDetailScreen(postId: original.id)))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: original != null
              ? Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            UserAvatar(
                                imageUrl: original.user?.profilePictureUrl,
                                name: name,
                                radius: 12),
                            const SizedBox(width: 7),
                            Expanded(
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w800))),
                            if (interactive)
                              Icon(Icons.arrow_outward_rounded,
                                  size: 16, color: colors.primary),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                              text.isNotEmpty
                                  ? text
                                  : original.type == PostType.video
                                      ? 'Video post'
                                      : original.type == PostType.image
                                          ? 'Photo post'
                                          : 'Text post',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium),
                        ]),
                  ),
                  if (media?.isNotEmpty == true &&
                      original.type == PostType.image) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(media!,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.square(
                              dimension: 54,
                              child: Icon(Icons.photo_outlined))),
                    ),
                  ] else if (original.type == PostType.video) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.play_circle_outline_rounded,
                        color: colors.primary),
                  ],
                ])
              : Text('Original post is no longer available.',
                  style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}
