// lib/features/post/presentation/widgets/video_player_widget.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool loop;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false, // Default to not autoplay
    this.loop = false, // Default to not loop
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    try {
      await _videoPlayerController.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: widget.autoPlay,
        looping: widget.loop,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        // Optional: customize controls
        // customControls: const CupertinoControls(
        //   backgroundColor: Colors.black54,
        //   iconColor: Colors.white,
        // ),
        showOptions: false, // Hide default options like speed, quality
        allowFullScreen: true,
        allowMuting: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Text('Could not play this video.'));
    return _isInitialized && _chewieController != null
        ? Chewie(
            controller: _chewieController!,
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }
}
