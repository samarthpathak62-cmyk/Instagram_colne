import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/core/media/picked_media_preview.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:video_player/video_player.dart';

class CreatePostScreen extends StatelessWidget {
  final ValueChanged<Post>? onCreated;
  final VoidCallback? onClose;
  final bool reelMode;
  final bool photoMode;
  final String? groupId;
  final String? groupName;

  const CreatePostScreen(
      {super.key,
      this.onCreated,
      this.onClose,
      this.reelMode = false,
      this.photoMode = false,
      this.groupId,
      this.groupName});

  @override
  Widget build(BuildContext context) => BlocProvider<PostBloc>(
        create: (_) => di.sl<PostBloc>(),
        child: _Composer(
            onCreated: onCreated,
            onClose: onClose,
            reelMode: reelMode,
            photoMode: photoMode,
            groupId: groupId,
            groupName: groupName),
      );
}

class _Composer extends StatefulWidget {
  final ValueChanged<Post>? onCreated;
  final VoidCallback? onClose;
  final bool reelMode;
  final bool photoMode;
  final String? groupId;
  final String? groupName;

  const _Composer(
      {required this.onCreated,
      required this.onClose,
      required this.reelMode,
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

  @override
  void dispose() {
    _text.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _pick({bool video = false}) async {
    if (_picking || _sending) return;
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
        final size = await file.length();
        if (size == 0 || size > 50 * 1024 * 1024)
          throw const FormatException(
              'Each file needs to be between 1 byte and 50 MB.');
      }
      if (!mounted) return;
      _clearMedia();
      setState(() {
        _media = files;
        _type = video ? PostType.video : PostType.image;
      });
      if (video) _previewVideo(files.single);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'Could not pick this media. Try a different file.');
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
  }

  bool _canPublish(String text) =>
      !_sending &&
      !_picking &&
      (widget.reelMode
          ? _type == PostType.video
          : widget.photoMode
              ? _type == PostType.image
              : _media.isNotEmpty || text.trim().isNotEmpty);

  void _publish() {
    if (!_canPublish(_text.text)) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated) return;
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
          groupId: widget.groupId,
        ));
  }

  @override
  Widget build(BuildContext context) => BlocListener<PostBloc, PostState>(
        listener: (context, state) {
          if (state is PostUploadSuccess) {
            final wasReel = widget.reelMode;
            setState(() {
              _clearMedia();
              _sending = false;
              _text.clear();
            });
            context.read<FeedCubit>().refresh();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(wasReel ? 'Reel published' : 'Post published')));
            if (widget.onCreated != null) {
              widget.onCreated!(state.newPost);
            } else {
              Navigator.of(context).maybePop();
            }
          } else if (state is PostOperationFailure) {
            setState(() {
              _sending = false;
              _error = state.message;
            });
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
                tooltip: 'Close composer',
                icon: const Icon(Icons.close_rounded),
                onPressed: _sending
                    ? null
                    : widget.onClose ?? () => Navigator.of(context).maybePop()),
            title: Text(widget.groupId != null
                ? 'New group post'
                : widget.reelMode
                    ? 'New reel'
                    : widget.photoMode
                        ? 'New photo post'
                        : 'New post'),
            actions: [
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _text,
                    builder: (context, value, _) => FilledButton(
                        onPressed: _canPublish(value.text) ? _publish : null,
                        child: const Text('Publish')),
                  ))
            ],
          ),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 645),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (widget.groupName != null) ...[
                        ListTile(
                          leading: Icon(Icons.groups_outlined,
                              color: context.veyroColors.primary),
                          title: Text(widget.groupName!,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle:
                              const Text('Public group • visible on Veyro'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        widget.reelMode
                                            ? 'Share a short video'
                                            : widget.photoMode
                                                ? 'Share your photos'
                                                : 'What’s on your mind?',
                                        style: context.veyroText.headlineSmall),
                                    const SizedBox(height: 6),
                                    Text(
                                        widget.reelMode
                                            ? 'Choose a video up to 50 MB. Add a caption if you like.'
                                            : widget.photoMode
                                                ? 'Choose up to eight photos and add a caption.'
                                                : 'Write an update, add photos, or share a video.',
                                        style: context.veyroText.bodyMedium),
                                    const SizedBox(height: 18),
                                    TextField(
                                      controller: _text,
                                      enabled: !_sending,
                                      decoration: InputDecoration(
                                          labelText: _media.isEmpty &&
                                                  !widget.reelMode &&
                                                  !widget.photoMode
                                              ? 'Post text'
                                              : 'Caption (optional)',
                                          hintText: 'Start writing…',
                                          alignLabelWithHint: true),
                                      minLines: 3,
                                      maxLines: 7,
                                      maxLength: Post.maxDescriptionLength,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                    ),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      if (!widget.reelMode)
                                        OutlinedButton.icon(
                                            onPressed: _picking || _sending
                                                ? null
                                                : () => _pick(),
                                            icon: const Icon(
                                                Icons.photo_library_outlined,
                                                size: 19),
                                            label: const Text('Add photos')),
                                      if (!widget.photoMode)
                                        OutlinedButton.icon(
                                            onPressed: _picking || _sending
                                                ? null
                                                : () => _pick(video: true),
                                            icon: const Icon(
                                                Icons.videocam_outlined,
                                                size: 19),
                                            label: const Text('Add video')),
                                      if (_media.isNotEmpty)
                                        TextButton.icon(
                                            onPressed: _picking || _sending
                                                ? null
                                                : () => setState(_clearMedia),
                                            icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18),
                                            label: const Text('Remove media')),
                                    ]),
                                    if (_error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(_error!,
                                              style: TextStyle(
                                                  color: context
                                                      .veyroColors.error))),
                                    if (_sending || _picking) ...[
                                      const SizedBox(height: 16),
                                      const LinearProgressIndicator(),
                                      const SizedBox(height: 8),
                                      Text(_sending
                                          ? 'Publishing…'
                                          : 'Preparing media…'),
                                    ],
                                  ]))),
                      if (_media.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _preview()
                      ],
                    ],
                  ))),
        ),
      );

  Widget _preview() {
    if (_type == PostType.image) {
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
                    dimension: 100, child: Icon(Icons.broken_image_outlined)),
              )),
      ]);
    }
    final video = _video;
    return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _videoFailed
              ? const Center(
                  child: Text(
                      'Preview unavailable. MP4 works best across devices.'))
              : video?.value.isInitialized == true
                  ? Center(
                      child: AspectRatio(
                          aspectRatio: video!.value.aspectRatio,
                          child: VideoPlayer(video)))
                  : const Center(child: CircularProgressIndicator()),
        ));
  }
}
