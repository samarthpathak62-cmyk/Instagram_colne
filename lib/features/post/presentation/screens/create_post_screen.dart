import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/media/picked_media_preview.dart';
import 'package:instagram_clone/core/media/supabase_media_upload.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/draft_pop_scope.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:video_player/video_player.dart';

class CreatePostScreen extends StatelessWidget {
  final ValueChanged<Post>? onCreated;
  final bool photoMode;
  final String? groupId;
  final String? groupName;

  const CreatePostScreen(
      {super.key,
      this.onCreated,
      this.photoMode = false,
      this.groupId,
      this.groupName});

  @override
  Widget build(BuildContext context) => BlocProvider<PostBloc>(
      create: (_) => di.sl<PostBloc>(),
      child: _Composer(
          onCreated: onCreated,
          photoMode: photoMode,
          groupId: groupId,
          groupName: groupName));
}

class _Composer extends StatefulWidget {
  final ValueChanged<Post>? onCreated;
  final bool photoMode;
  final String? groupId;
  final String? groupName;

  const _Composer(
      {required this.onCreated,
      required this.photoMode,
      this.groupId,
      this.groupName});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  List<XFile> _media = const [];
  PostType _type = PostType.text;
  VideoPlayerController? _video;
  bool _videoFailed = false;
  bool _picking = false;
  bool _sending = false;
  String? _error;

  bool get _busy => _picking || _sending;

  @override
  void dispose() {
    _text.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _pick({bool video = false}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file =
          video ? await _picker.pickVideo(source: ImageSource.gallery) : null;
      final files =
          video ? [if (file != null) file] : await _picker.pickMultiImage();
      if (!mounted || files.isEmpty) return;
      if (files.length > 8)
        throw const FormatException('Select up to eight photos.');
      for (final file in files) {
        await validateMediaFile(file, isVideo: video);
      }
      if (!mounted) return;
      setState(() {
        _clearMedia();
        _media = files;
        _type = video ? PostType.video : PostType.image;
      });
      if (video) unawaited(_previewVideo(files.single));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FileUploadException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Couldn’t pick this media. Try a different file.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _previewVideo(XFile file) async {
    final video = pickedVideoController(file);
    _video = video;
    try {
      await video.initialize();
      if (mounted && _video == video) setState(() {});
    } catch (_) {
      if (mounted && _video == video) setState(() => _videoFailed = true);
    }
  }

  void _clearMedia() {
    _video?.dispose();
    _video = null;
    _videoFailed = false;
    _media = const [];
    _type = PostType.text;
    _error = null;
  }

  bool _canPublish(String text) =>
      !_busy &&
      (widget.photoMode
          ? _type == PostType.image
          : _media.isNotEmpty || text.trim().isNotEmpty);

  void _publish() {
    final auth = context.read<AuthBloc>().state;
    if (!_canPublish(_text.text) || auth is! Authenticated) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    context.read<PostBloc>().add(CreateNewPost(
        authorId: auth.user.id,
        type: _type,
        mediaFiles: List.of(_media),
        description: _text.text.trim(),
        groupId: widget.groupId));
  }

  @override
  Widget build(BuildContext context) => BlocListener<PostBloc, PostState>(
        listener: (context, state) {
          if (state is PostUploadSuccess) {
            unawaited(context.read<FeedCubit>().refresh());
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Post published')));
            if (widget.onCreated != null) {
              widget.onCreated!(state.newPost);
            } else {
              Navigator.of(context).pop(state.newPost);
            }
          } else if (state is PostOperationFailure) {
            setState(() {
              _sending = false;
              _error = state.message;
            });
          }
        },
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          child: _body(),
          builder: (context, value, body) => DraftPopScope(
            hasDraft: value.text.trim().isNotEmpty || _media.isNotEmpty,
            uploading: _sending,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                    tooltip: 'Close composer',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).maybePop()),
                title: Text(widget.groupId != null
                    ? 'New group post'
                    : widget.photoMode
                        ? 'New photo post'
                        : 'New post'),
                actions: [
                  Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: FilledButton(
                          onPressed: _canPublish(value.text) ? _publish : null,
                          child: const Text('Publish')))
                ],
              ),
              body: body,
            ),
          ),
        ),
      );

  Widget _body() => SafeArea(
      top: false,
      child: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 638),
        child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 26),
            children: [
              _author(),
              const SizedBox(height: 12),
              if (widget.photoMode) ...[
                _mediaArea(),
                const SizedBox(height: 14)
              ],
              TextField(
                  controller: _text,
                  enabled: !_sending,
                  decoration: InputDecoration(
                      labelText: _media.isEmpty && !widget.photoMode
                          ? 'Post text'
                          : 'Caption (optional)',
                      alignLabelWithHint: true),
                  minLines: 3,
                  maxLines: 7,
                  maxLength: Post.maxDescriptionLength,
                  textCapitalization: TextCapitalization.sentences),
              if (!widget.photoMode) _mediaArea(),
              if (_error != null)
                Padding(
                    padding: const EdgeInsetsDirectional.only(top: 12),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(_error!,
                            style:
                                TextStyle(color: context.veyroColors.error)))),
              if (_busy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
                const SizedBox(height: 7),
                Text(_sending ? 'Publishing…' : 'Preparing media…',
                    style: context.veyroText.bodySmall),
              ],
            ]),
      )));

  Widget _author() {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    final name = user?.name ?? user?.username;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(
          child: UserAvatar(
              imageUrl: user?.profileImageUrl, name: name, radius: 21)),
      title: Text(name ?? 'Your post',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.veyroText.titleSmall),
      subtitle: Text(
          widget.groupName == null
              ? 'Public post'
              : 'Posting in ${widget.groupName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.veyroText.bodySmall),
      trailing: Icon(
          widget.groupName == null
              ? Icons.public_rounded
              : Icons.groups_outlined,
          color: context.veyroColors.onSurfaceVariant,
          size: 20),
    );
  }

  Widget _mediaArea() {
    final colors = context.veyroColors;
    final buttons = Wrap(
        alignment:
            widget.photoMode ? WrapAlignment.center : WrapAlignment.start,
        spacing: 8,
        runSpacing: 5,
        children: [
          FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _pick(),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Add photos')),
          if (!widget.photoMode)
            FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _pick(video: true),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Add video')),
          if (_media.isNotEmpty)
            TextButton(
                onPressed: _busy ? null : () => setState(_clearMedia),
                child: const Text('Remove media')),
        ]);
    if (_media.isEmpty && !widget.photoMode) return buttons;
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: widget.photoMode
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (_media.isNotEmpty)
                  _preview()
                else ...[
                  const SizedBox(height: 10),
                  VeyroOrbitRing(
                      glowing: false,
                      surface: colors.surfaceContainer,
                      child: CircleAvatar(
                          radius: 24,
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: const Icon(Icons.photo_library_outlined))),
                  const SizedBox(height: 9),
                  Text('Choose up to eight photos',
                      textAlign: TextAlign.center,
                      style: context.veyroText.bodySmall),
                ],
                const SizedBox(height: 10),
                buttons,
              ],
            )));
  }

  Widget _preview() {
    if (_type == PostType.image)
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (final file in _media)
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(
                  image: pickedImageProvider(file),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.square(
                      dimension: 100,
                      child: Icon(Icons.broken_image_outlined)))),
      ]);
    final video = _video;
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
              color: context.veyroColors.surfaceContainerHigh,
              child: _videoFailed
                  ? const Center(
                      child: Text(
                          'Preview unavailable. MP4 works best across devices.',
                          textAlign: TextAlign.center))
                  : video?.value.isInitialized == true
                      ? Center(
                          child: AspectRatio(
                              aspectRatio: video!.value.aspectRatio,
                              child: VideoPlayer(video)))
                      : const Center(child: CircularProgressIndicator())),
        ));
  }
}
