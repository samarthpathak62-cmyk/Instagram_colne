import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/explore/domain/post_topics.dart';
import 'package:instagram_clone/features/explore/presentation/screens/search_screen.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/groups/presentation/group_post_origin.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_actions.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_header.dart';
import 'package:instagram_clone/features/post/presentation/widgets/shared_post_preview.dart';
import 'package:instagram_clone/features/post/presentation/widgets/video_player_widget.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool inDetail;
  final bool showGroupOrigin;
  final bool canModerate;

  const PostCard(
      {super.key,
      required this.post,
      this.inDetail = false,
      this.showGroupOrigin = true,
      this.canModerate = false});

  @override
  Widget build(BuildContext context) {
    final state =
        context.select((PostInteractionsCubit cubit) => cubit.forPost(post.id));
    if (state.deleted) return const SizedBox.shrink();
    final text = post.shareKind == PostShareKind.repost ? '' : state.text(post);
    final hasMedia = post.type != PostType.text;
    final media = post.mediaUrls.where((url) => url.isNotEmpty).toList();
    final caption = text.isEmpty
        ? null
        : _Caption(text: text, username: hasMedia ? post.user?.username : null);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 7),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (post.shareKind != null)
          Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(15, 10, 15, 0),
              child: Row(children: [
                Icon(
                    post.shareKind == PostShareKind.repost
                        ? Icons.repeat_rounded
                        : Icons.format_quote_rounded,
                    size: 16,
                    color: context.veyroColors.primary),
                const SizedBox(width: 6),
                VeyroEyebrow(post.shareKind == PostShareKind.repost
                    ? 'Reposted'
                    : 'Quoted post'),
              ])),
        PostHeader(
            post: post, showOpenPost: !inDetail, canModerate: canModerate),
        if (showGroupOrigin && post.groupId != null)
          Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: GroupPostOrigin(post: post)),
        if (!hasMedia && caption != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 9), child: caption),
        if (post.shareKind != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 1, 14, 6),
              child: SharedPostPreview(post: post.sharedPost)),
        if (hasMedia && media.isNotEmpty)
          ColoredBox(
              color: context.veyroColors.surfaceContainerLowest,
              child: post.type == PostType.video
                  ? AspectRatio(
                      aspectRatio: 16 / 10,
                      child: VideoPlayerWidget(
                          key: ValueKey(media.first),
                          videoUrl: media.first,
                          loadOnTap: true))
                  : _PostPhotos(
                      urls: media,
                      onDoubleTap: () => showPostActionError(
                          context,
                          context
                              .read<PostInteractionsCubit>()
                              .toggleLike(post, likeOnly: true)))),
        if (hasMedia && media.isEmpty)
          const Padding(
              padding: EdgeInsets.all(18),
              child: Text('Media is no longer available.')),
        PostActions(post: post, caption: hasMedia ? caption : null),
      ]),
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  final String? username;
  const _Caption({required this.text, this.username});

  @override
  Widget build(BuildContext context) {
    final topics = postTopics(text);
    final style = (username == null
            ? context.veyroText.bodyLarge
            : context.veyroText.bodyMedium)
        ?.copyWith(height: 1.48);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText.rich(TextSpan(style: style, children: [
        if (username?.isNotEmpty == true)
          TextSpan(
              text: '$username  ',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        TextSpan(text: text),
      ])),
      if (topics.isNotEmpty)
        Wrap(spacing: 3, children: [
          for (final topic in topics)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => SearchScreen(initialQuery: topic))),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 5)),
              child: Text(topic),
            ),
        ]),
    ]);
  }
}

class _PostPhotos extends StatefulWidget {
  final List<String> urls;
  final VoidCallback onDoubleTap;
  const _PostPhotos({required this.urls, required this.onDoubleTap});

  @override
  State<_PostPhotos> createState() => _PostPhotosState();
}

class _PostPhotosState extends State<_PostPhotos>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 760));
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _like() {
    widget.onDoubleTap();
    if (!MediaQuery.disableAnimationsOf(context)) _pulse.forward(from: 0);
  }

  void _go(int index) => _pages.animateToPage(index,
      duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);

  Widget _image(String url, int index, {required bool single}) =>
      GestureDetector(
        onDoubleTap: _like,
        child: Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.contain,
          cacheWidth: 1200,
          semanticLabel: 'Post photo ${index + 1}',
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const AspectRatio(
                  aspectRatio: 1,
                  child: Center(child: CircularProgressIndicator())),
          errorBuilder: (_, __, ___) => single
              ? const AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Center(child: Text('Could not load photo.')))
              : const Center(child: Text('Could not load photo.')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final single = widget.urls.length == 1;
    return LayoutBuilder(
        builder: (context, box) =>
            Stack(alignment: Alignment.center, children: [
              if (single)
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight:
                            (box.maxWidth * 1.25).clamp(0.0, 700.0).toDouble()),
                    child: _image(widget.urls.single, 0, single: true))
              else
                AspectRatio(
                    aspectRatio: 4 / 5,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: widget.urls.length,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (_, index) =>
                          _image(widget.urls[index], index, single: false),
                    )),
              if (!single) ...[
                if (_index > 0)
                  PositionedDirectional(
                      start: 5,
                      child: IconButton.filledTonal(
                          tooltip: 'Previous photo',
                          onPressed: () => _go(_index - 1),
                          icon: const Icon(Icons.chevron_left_rounded))),
                if (_index < widget.urls.length - 1)
                  PositionedDirectional(
                      end: 5,
                      child: IconButton.filledTonal(
                          tooltip: 'Next photo',
                          onPressed: () => _go(_index + 1),
                          icon: const Icon(Icons.chevron_right_rounded))),
                PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .65),
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          child: Text('${_index + 1} / ${widget.urls.length}',
                              style: const TextStyle(color: Colors.white))),
                    )),
              ],
              IgnorePointer(
                  child: ExcludeSemantics(
                      child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = _pulse.value;
                  if (t <= 0 || t >= 1) return const SizedBox.shrink();
                  return Opacity(
                      opacity: t < .7 ? 1 : (1 - t) / .3,
                      child: Transform.scale(
                          scale: .55 +
                              Curves.easeOutBack.transform(
                                      (t * 3).clamp(0.0, 1.0).toDouble()) *
                                  .45,
                          child: child));
                },
                child: const Icon(Icons.favorite_rounded,
                    color: VeyroTheme.frost,
                    size: 78,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 16)]),
              ))),
            ]));
  }
}
