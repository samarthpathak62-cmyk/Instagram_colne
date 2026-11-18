import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:instagram_clone/core/media/picked_media_preview.dart';
import 'package:instagram_clone/core/media/supabase_media_upload.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/draft_pop_scope.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:video_player/video_player.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  static Future<Post?> open(BuildContext context) =>
      Navigator.of(context).push<Post>(MaterialPageRoute(
        builder: (_) => BlocProvider<PostBloc>(
            create: (_) => sl<PostBloc>(), child: const CreateReelScreen()),
      ));

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  XFile? _file;
  VideoPlayerController? _preview;
  bool _picking = false;
  bool _sharing = false;
  String? _error;

  bool get _busy => _picking || _sharing;

  Future<void> _choose() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final current = _preview;
    if (current?.value.isPlaying == true) unawaited(current!.pause());
    setState(() {
      _picking = true;
      _error = null;
    });
    VideoPlayerController? candidate;
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (!mounted || file == null) return;
      await validateMediaFile(file, isVideo: true);
      if (!mounted) return;
      candidate = pickedVideoController(file);
      await candidate.initialize().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (!candidate.value.isInitialized ||
          candidate.value.duration == Duration.zero) {
        throw const FormatException('Empty video');
      }
      // A bad replacement (or a canceled picker) doesn't lose the old draft.
      final previous = _preview;
      setState(() {
        _file = file;
        _preview = candidate;
      });
      candidate = null;
      if (previous != null) unawaited(previous.dispose());
    } on FileUploadException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Couldn’t preview this video. Try another clip, preferably MP4.');
    } finally {
      if (candidate != null) unawaited(candidate.dispose());
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _togglePreview(VideoPlayerController video) async {
    try {
      if (video.value.isPlaying) {
        await video.pause();
      } else {
        if (video.value.isCompleted) await video.seekTo(Duration.zero);
        await video.play();
      }
    } catch (_) {
      if (mounted && _preview == video)
        setState(
            () => _error = 'Couldn’t play the preview. Try another video.');
    }
  }

  void _share() {
    final file = _file;
    final preview = _preview;
    final auth = context.read<AuthBloc>().state;
    if (file == null ||
        preview == null ||
        preview.value.hasError ||
        _busy ||
        auth is! Authenticated) return;
    FocusScope.of(context).unfocus();
    if (preview.value.isPlaying) unawaited(preview.pause());
    setState(() {
      _sharing = true;
      _error = null;
    });
    context.read<PostBloc>().add(CreateNewPost(
        authorId: auth.user.id,
        type: PostType.video,
        mediaFiles: [file],
        description: _caption.text.trim()));
  }

  @override
  void dispose() {
    _preview?.dispose();
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    final video = _preview;
    return BlocListener<PostBloc, PostState>(
      listener: (context, state) {
        if (state is PostUploadSuccess) {
          Navigator.of(context).pop(state.newPost);
        } else if (state is PostOperationFailure) {
          setState(() {
            _sharing = false;
            _error = state.message;
          });
        }
      },
      child: DraftPopScope(
        hasDraft: _file != null,
        uploading: _sharing,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
                tooltip: 'Close reel composer',
                icon: const Icon(Icons.close_rounded),
                onPressed:
                    _sharing ? null : () => Navigator.of(context).maybePop()),
            title: const Text('New reel'),
            actions: [
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: video == null
                      ? const FilledButton(
                          onPressed: null, child: Text('Share'))
                      : ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: video,
                          builder: (context, value, _) => FilledButton(
                              onPressed: _busy || value.hasError || user == null
                                  ? null
                                  : _share,
                              child: const Text('Share')))),
            ],
          ),
          body: SafeArea(
              top: false,
              child: Center(
                  child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: video == null ? 500 : 760),
                child: LayoutBuilder(builder: (context, constraints) {
                  final name = user?.name ?? user?.username;
                  final details = _details(name, user?.profilePictureUrl);
                  return ListView(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 28),
                      children: [
                        if (_busy) ...[
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 9),
                          Semantics(
                              liveRegion: true,
                              child: Text(
                                  _sharing
                                      ? 'Sharing reel…'
                                      : 'Preparing video…',
                                  style: context.veyroText.labelLarge)),
                          const SizedBox(height: 13),
                        ],
                        if (_error != null) ...[
                          Semantics(
                              liveRegion: true,
                              child: Text(_error!,
                                  style: context.veyroText.bodyMedium?.copyWith(
                                      color: context.veyroColors.error))),
                          const SizedBox(height: 13),
                        ],
                        if (video == null)
                          _emptyPicker()
                        else if (constraints.maxWidth >= 650)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _stage(video)),
                                const SizedBox(width: 18),
                                Expanded(child: details),
                              ])
                        else ...[
                          _stage(video),
                          const SizedBox(height: 16),
                          details,
                        ],
                      ]);
                }),
              ))),
        ),
      ),
    );
  }

  Widget _emptyPicker() {
    final colors = context.veyroColors;
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
          child: Column(children: [
            VeyroOrbitRing(
                surface: colors.surface,
                glowing: false,
                child: CircleAvatar(
                    radius: 33,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: const Icon(Icons.movie_outlined, size: 31))),
            const SizedBox(height: 20),
            Text('Choose a video',
                style: context.veyroText.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 7),
            Text(
                'Pick a clip to preview, add a caption if you like, then share it to Reels.',
                style: context.veyroText.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
                icon: const Icon(Icons.video_library_outlined),
                onPressed: _busy ? null : _choose,
                label: const Text('Choose video')),
            const SizedBox(height: 14),
            Text('Up to 50 MB · MP4 recommended',
                textAlign: TextAlign.center,
                style: context.veyroText.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
          ]),
        ));
  }

  Widget _stage(VideoPlayerController video) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Preview', style: context.veyroText.titleMedium),
        const SizedBox(height: 9),
        ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 300,
              child: ColoredBox(
                  color: VeyroTheme.midnight,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: video,
                    child: Center(
                        child: AspectRatio(
                            aspectRatio: video.value.aspectRatio,
                            child: VideoPlayer(video))),
                    builder: (context, value, player) {
                      if (value.hasError)
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                    'Preview unavailable. Choose another video.',
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: VeyroTheme.frost))));
                      return Stack(fit: StackFit.expand, children: [
                        player!,
                        PositionedDirectional(
                            start: 8,
                            bottom: 8,
                            child: IconButton.filledTonal(
                                tooltip: value.isPlaying
                                    ? 'Pause preview'
                                    : 'Play preview',
                                onPressed:
                                    _busy ? null : () => _togglePreview(video),
                                icon: Icon(value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded))),
                      ]);
                    },
                  )),
            )),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: Text(_file!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.veyroText.bodySmall)),
          TextButton(
              onPressed: _busy ? null : _choose,
              child: const Text('Change video')),
        ]),
      ]);

  Widget _details(String? user, String? avatar) {
    final colors = context.veyroColors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        ExcludeSemantics(
            child: UserAvatar(name: user, imageUrl: avatar, radius: 17)),
        const SizedBox(width: 9),
        Expanded(
            child: Text(user ?? 'Your reel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.veyroText.titleSmall)),
      ]),
      const SizedBox(height: 12),
      TextField(
          controller: _caption,
          enabled: !_sharing,
          minLines: 2,
          maxLines: 5,
          maxLength: Post.maxDescriptionLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Caption (optional)', alignLabelWithHint: true)),
      const SizedBox(height: 5),
      Row(children: [
        Icon(Icons.public_rounded, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
            child: Text('Public reel',
                style: context.veyroText.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant))),
      ]),
    ]);
  }
}
