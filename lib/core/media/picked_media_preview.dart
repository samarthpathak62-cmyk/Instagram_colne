import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

ImageProvider<Object> pickedImageProvider(XFile file) =>
    kIsWeb ? NetworkImage(file.path) : FileImage(File(file.path));

VideoPlayerController pickedVideoController(XFile file) => kIsWeb
    ? VideoPlayerController.networkUrl(Uri.parse(file.path))
    : VideoPlayerController.file(File(file.path));
