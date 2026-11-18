import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool loadOnTap;
  final bool autoPlay;
  final bool muted;
  final bool loop;

  const VideoPlayerWidget(
      {super.key,
      required this.videoUrl,
      this.loadOnTap = false,
      this.autoPlay = false,
      this.muted = false,
      this.loop = false});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.loadOnTap) _open(play: widget.autoPlay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == false || !TickerMode.of(context)) {
      if (_chewie?.isFullScreen != true) _video?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _video?.pause();
  }

  Future<void> _open({required bool play}) async {
    if (_video != null && !_failed) return;
    final previous = _video;
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    setState(() {
      _failed = false;
      _video = controller;
    });
    try {
      await previous?.dispose();
      await controller.initialize();
      if (!mounted || _video != controller) return;
      if (widget.muted) await controller.setVolume(0);
      if (!mounted || _video != controller) return;
      final onScreen =
          (ModalRoute.isCurrentOf(context) ?? true) && TickerMode.of(context);
      setState(() => _chewie = ChewieController(
            videoPlayerController: controller,
            autoPlay: play && onScreen,
            looping: widget.loop,
            aspectRatio: controller.value.aspectRatio,
            showOptions: false,
            allowMuting: true,
            errorBuilder: (_, __) => const Center(
                child: Text('Playback is not available for this video.',
                    style: TextStyle(color: Colors.white))),
          ));
    } catch (_) {
      if (mounted && _video == controller) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: _chewie != null
            ? Chewie(controller: _chewie!)
            : Center(
                child: _video != null && !_failed
                    ? const CircularProgressIndicator()
                    : FilledButton.icon(
                        icon: Icon(_failed
                            ? Icons.refresh_rounded
                            : Icons.play_arrow_rounded),
                        label: Text(_failed ? 'Retry video' : 'Play video'),
                        onPressed: () => _open(play: true),
                      )),
      );
}
