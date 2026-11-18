import 'package:flutter/material.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';

class StoryViewScreen extends StatefulWidget {
  final Story story;
  final int initialIndex;
  final ValueChanged<String> onSeen;

  const StoryViewScreen(
      {super.key,
      required this.story,
      this.initialIndex = 0,
      required this.onSeen});

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progress;
  late int _index;
  StoryItem get _item => widget.story.items[_index];
  VideoPlayerController? _video;
  bool _paused = false;
  bool _failed = false;
  bool _closing = false;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.initialIndex;
    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted && !_paused)
      _togglePause();
  }

  Future<void> _open() async {
    _video?.dispose();
    _video = null;
    _progress.reset();
    _failed = false;
    _advancing = false;
    final item = _item;
    if (item.mediaType == StoryMediaType.image) {
      _progress.duration = const Duration(seconds: 5);
      if (!_paused) _progress.forward();
      _markSeen(item);
      return;
    }
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(item.mediaUrl));
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted || _video != controller) return;
      // Muted video can autoplay in mobile and desktop browsers.
      await controller.setVolume(0);
      if (!mounted || _video != controller) return;
      controller.addListener(() {
        if (mounted &&
            _video == controller &&
            controller.value.isCompleted &&
            !_advancing) {
          _advancing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _video == controller) _next();
          });
        }
      });
      setState(() {});
      if (!_paused) await controller.play();
      if (mounted && _video == controller) _markSeen(item);
    } catch (_) {
      if (mounted && _video == controller) setState(() => _failed = true);
    }
  }

  void _markSeen(StoryItem item) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSeen(item.id);
      });

  void _next() {
    if (_index + 1 == widget.story.items.length) {
      _close();
      return;
    }
    setState(() {
      _index++;
      _open();
    });
  }

  void _previous() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _open();
    });
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _progress.stop();
    _video?.pause();
    Navigator.of(context).pop();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _progress.stop();
      if (_video?.value.isInitialized == true) _video?.pause();
    } else if (_video?.value.isInitialized == true) {
      _video?.play();
    } else if (_item.mediaType == StoryMediaType.image) {
      _progress.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VeyroTheme.midnight,
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 3),
                          child: Row(children: [
                            for (var i = 0; i < widget.story.items.length; i++)
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: i != _index
                                            ? _bar(i < _index ? 1 : 0)
                                            : _video != null
                                                ? ValueListenableBuilder<
                                                        VideoPlayerValue>(
                                                    valueListenable: _video!,
                                                    builder: (_, value, __) {
                                                      final duration = value
                                                          .duration
                                                          .inMilliseconds;
                                                      return _bar(duration <= 0
                                                          ? 0
                                                          : (value.position
                                                                      .inMilliseconds /
                                                                  duration)
                                                              .clamp(0.0, 1.0)
                                                              .toDouble());
                                                    })
                                                : AnimatedBuilder(
                                                    animation: _progress,
                                                    builder: (_, __) =>
                                                        _bar(_progress.value)),
                                      ))),
                          ])),
                      ListTile(
                        leading: UserAvatar(
                            imageUrl: widget.story.profileImageUrl, radius: 17),
                        title: Text('@${widget.story.username ?? 'veyro_user'}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(timeago.format(_item.createdAt),
                            style: const TextStyle(color: Colors.white70)),
                        trailing: IconButton(
                            tooltip: 'Close story',
                            onPressed: _close,
                            icon: const Icon(Icons.close, color: Colors.white)),
                      ),
                      Expanded(
                          child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) =>
                                        details.localPosition.dx <
                                                constraints.maxWidth / 2
                                            ? _previous()
                                            : _next(),
                                    child: SizedBox.expand(
                                        child: Center(child: _media())),
                                  ))),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          children: [
                            IconButton(
                                tooltip: 'Previous story',
                                onPressed: _index > 0 ? _previous : null,
                                icon: Icon(Icons.chevron_left_rounded,
                                    color: _index > 0
                                        ? Colors.white
                                        : Colors.white38)),
                            IconButton(
                                tooltip:
                                    _paused ? 'Resume story' : 'Pause story',
                                onPressed: _failed ? null : _togglePause,
                                icon: Icon(
                                    _paused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    color: Colors.white)),
                            if (_video?.value.isInitialized == true && !_failed)
                              ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: _video!,
                                  builder: (context, value, _) => IconButton(
                                        tooltip: value.volume > 0
                                            ? 'Mute story'
                                            : 'Unmute story',
                                        onPressed: () => _video?.setVolume(
                                            value.volume > 0 ? 0 : 1),
                                        icon: Icon(
                                            value.volume > 0
                                                ? Icons.volume_up_rounded
                                                : Icons.volume_off_rounded,
                                            color: Colors.white),
                                      )),
                            IconButton(
                                tooltip: 'Next story',
                                onPressed: _next,
                                icon: const Icon(Icons.chevron_right_rounded,
                                    color: Colors.white)),
                          ]),
                    ])))),
      );

  Widget _bar(double value) => LinearProgressIndicator(
      minHeight: 3,
      value: value,
      color: VeyroTheme.lilac,
      backgroundColor: Colors.white30);

  Widget _media() {
    final video = _video;
    if (_failed)
      return FilledButton.icon(
          onPressed: () => setState(() {
                _open();
              }),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry story video'));
    if (_item.mediaType == StoryMediaType.video) {
      if (video == null || !video.value.isInitialized)
        return const CircularProgressIndicator();
      return AspectRatio(
          aspectRatio: video.value.aspectRatio, child: VideoPlayer(video));
    }
    return Image.network(_item.mediaUrl,
        key: ValueKey(_item.id),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text('Could not load story photo.',
            style: TextStyle(color: Colors.white70)));
  }
}
