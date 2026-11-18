import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/core/media/picked_media_preview.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:instagram_clone/features/story/presentation/bloc/story_bloc.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _picker = ImagePicker();
  XFile? _file;
  StoryMediaType _type = StoryMediaType.image;
  bool _picking = false;
  bool _uploading = false;
  String? _error;

  Future<void> _pick(StoryMediaType type) async {
    if (_picking || _uploading) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = type == StoryMediaType.video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted || file == null) return;
      final size = await file.length();
      if (!mounted) return;
      setState(() {
        if (size == 0 || size > 50 * 1024 * 1024) {
          _error = 'Choose a nonempty photo or video up to 50 MB.';
        } else {
          _type = type;
          _file = file;
        }
      });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not pick this media. Try another file.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _publish() {
    final file = _file;
    final auth = context.read<AuthBloc>().state;
    if (file == null || auth is! Authenticated || _picking || _uploading)
      return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    context.read<StoryBloc>().add(CreateNewStoryItem(
        userId: auth.user.id, mediaFile: file, mediaType: _type));
  }

  @override
  Widget build(BuildContext context) => BlocListener<StoryBloc, StoryState>(
        listener: (context, state) {
          if (state is StoryUploadSuccess) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Story published')));
            Navigator.of(context).pop(true);
          } else if (state is StoryOperationFailure) {
            setState(() {
              _uploading = false;
              _error = state.message;
            });
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('New story'), actions: [
            Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: FilledButton(
                  onPressed:
                      _file == null || _picking || _uploading ? null : _publish,
                  child: const Text('Publish story'),
                )),
          ]),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 585),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Share a moment',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: 7),
                                    const Text(
                                        'Choose a photo or video. Stories are visible for 24 hours.'),
                                    const SizedBox(height: 15),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      OutlinedButton.icon(
                                          onPressed: _picking || _uploading
                                              ? null
                                              : () =>
                                                  _pick(StoryMediaType.image),
                                          icon:
                                              const Icon(Icons.image_outlined),
                                          label: const Text('Add photo')),
                                      OutlinedButton.icon(
                                          onPressed: _picking || _uploading
                                              ? null
                                              : () =>
                                                  _pick(StoryMediaType.video),
                                          icon: const Icon(
                                              Icons.videocam_outlined),
                                          label: const Text('Add video')),
                                      if (_file != null)
                                        TextButton(
                                            onPressed: _picking || _uploading
                                                ? null
                                                : () => setState(() {
                                                      _file = null;
                                                      _error = null;
                                                    }),
                                            child: const Text('Remove media')),
                                    ]),
                                    if (_file != null) ...[
                                      const SizedBox(height: 14),
                                      if (_type == StoryMediaType.image)
                                        ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxHeight: 260),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image(
                                                  image: pickedImageProvider(
                                                      _file!),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Text(
                                                          'Photo preview unavailable.')),
                                            ))
                                      else
                                        ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(Icons
                                                .play_circle_outline_rounded),
                                            title: Text(_file!.name,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                    ],
                                    if (_error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: Text(_error!,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error))),
                                    if (_picking || _uploading) ...[
                                      const SizedBox(height: 16),
                                      const LinearProgressIndicator()
                                    ],
                                  ]))),
                    ],
                  ))),
        ),
      );
}
