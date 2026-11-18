import 'package:instagram_clone/core/media/picked_media_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_event.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:video_player/video_player.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';

class CreatePostScreen extends StatelessWidget {
  final VoidCallback? onCreated;
  final VoidCallback? onClose;

  const CreatePostScreen({super.key, this.onCreated, this.onClose});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PostBloc>(
      create: (_) => di.sl<PostBloc>(),
      child: _CreatePostScreenContent(onCreated: onCreated, onClose: onClose),
    );
  }
}

class _CreatePostScreenContent extends StatefulWidget {
  final VoidCallback? onCreated;
  final VoidCallback? onClose;

  const _CreatePostScreenContent({this.onCreated, this.onClose});

  @override
  State<_CreatePostScreenContent> createState() =>
      _CreatePostScreenContentState();
}

class _CreatePostScreenContentState extends State<_CreatePostScreenContent> {
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  List<XFile> _selectedMedia = [];
  PostType _postType = PostType.image;
  VideoPlayerController? _videoController;
  bool _isUploading = false;
  int _currentMediaIndex = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia({required bool isVideo}) async {
    if (isVideo) {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        setState(() {
          _selectedMedia = [video];
          _postType = PostType.video;
          _currentMediaIndex = 0;
          _initializeVideoPlayer(video);
        });
      }
    } else {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() {
          _selectedMedia = images;
          _postType = PostType.image;
          _currentMediaIndex = 0;
          _videoController?.dispose();
          _videoController = null;
        });
      }
    }
  }

  void _initializeVideoPlayer(XFile file) {
    _videoController?.dispose();
    _videoController = pickedVideoController(file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController?.play();
        _videoController?.setLooping(true);
      });
  }

  void _uploadPost() {
    if (_selectedMedia.isEmpty) {
      _showSnackBar('Please select an image or video first.', isError: true);
      return;
    }

    final currentUserState = context.read<AuthBloc>().state;
    if (currentUserState is Authenticated) {
      final userId = currentUserState.user.id;
      context.read<PostBloc>().add(CreateNewPost(
            authorId: userId,
            type: _postType,
            mediaFiles: List<XFile>.of(_selectedMedia),
            description: _descriptionController.text.trim(),
          ));
    }
  }

  void _resetState() {
    setState(() {
      _selectedMedia.clear();
      _descriptionController.clear();
      _videoController?.dispose();
      _videoController = null;
      _isUploading = false;
      _currentMediaIndex = 0;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final colors = context.veyroColors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError ? colors.errorContainer : null,
      content: Text(
        message,
        style: isError ? TextStyle(color: colors.onErrorContainer) : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostBloc, PostState>(
      listener: (context, state) {
        if (state is PostUploading) {
          setState(() => _isUploading = true);
        } else if (state is PostUploadSuccess) {
          _showSnackBar('Post created successfully!');
          _resetState();
          context.read<FeedBloc>().add(const RefreshFeedEvent());
          widget.onCreated?.call();
        } else if (state is PostOperationFailure) {
          _showSnackBar('Failed to create post: ${state.message}',
              isError: true);
          setState(() => _isUploading = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close composer',
            icon: const Icon(Icons.close_rounded),
            onPressed: _isUploading
                ? null
                : widget.onClose ?? () => Navigator.of(context).maybePop(),
          ),
          title: const Text('New post'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton(
                onPressed:
                    _isUploading || _selectedMedia.isEmpty ? null : _uploadPost,
                child: const Text('Share'),
              ),
            ),
          ],
        ),
        body: _isUploading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Sharing your post…'),
                  ],
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      _buildMediaPreview(),
                      if (_selectedMedia.length > 1) _buildMediaIndicator(),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickMedia(isVideo: false),
                            icon: const Icon(Icons.photo_library_outlined,
                                size: 19),
                            label: const Text('Photos'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickMedia(isVideo: true),
                            icon: const Icon(Icons.videocam_outlined, size: 19),
                            label: const Text('Video'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Caption',
                          hintText: 'Write a caption…',
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    final colors = context.veyroColors;
    if (_selectedMedia.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _showMediaSelectionDialog,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child:
                      const Icon(Icons.add_photo_alternate_outlined, size: 31),
                ),
                const SizedBox(height: 16),
                Text('Add media', style: context.veyroText.titleLarge),
                const SizedBox(height: 7),
                Text(
                  'Choose one or more photos, or a video.',
                  textAlign: TextAlign.center,
                  style: context.veyroText.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: colors.surfaceContainer,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: _postType == PostType.image
              ? PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentMediaIndex = index),
                  itemCount: _selectedMedia.length,
                  itemBuilder: (context, index) => Image(
                    image: pickedImageProvider(_selectedMedia[index]),
                    fit: BoxFit.contain,
                  ),
                )
              : _videoController?.value.isInitialized == true
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildMediaIndicator() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          child: Text(
            '${_currentMediaIndex + 1} / ${_selectedMedia.length}',
            style: context.veyroText.bodySmall,
          ),
        ),
      );

  void _showMediaSelectionDialog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add media', style: context.veyroText.titleLarge),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: context.veyroColors.primary),
                title: const Text('Photos from gallery'),
                subtitle: const Text('Select one or more photos'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(isVideo: false);
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam_outlined,
                    color: context.veyroColors.primary),
                title: const Text('Video from gallery'),
                subtitle: const Text('Select a video file'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMedia(isVideo: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
