import 'dart:math';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/core/error/exceptions.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, SupabaseClient;

const _mimeTypes = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
  '.mp4': 'video/mp4',
  '.m4v': 'video/mp4',
  '.mov': 'video/quicktime',
  '.webm': 'video/webm',
  '.3gp': 'video/3gpp',
};

/// Validates picked media before a preview and again at the upload boundary.
Future<String> validateMediaFile(XFile file,
    {required bool isVideo, int maxSizeMb = 50}) async {
  final extension = path.extension(file.name).toLowerCase();
  final mimeType = _mimeTypes[extension];
  if (mimeType == null || !mimeType.startsWith(isVideo ? 'video/' : 'image/')) {
    throw FileUploadException(message: 'This media format is not supported.');
  }
  final size = await file.length();
  if (size == 0 || size > maxSizeMb * 1024 * 1024) {
    throw FileUploadException(
        message: 'Choose a nonempty file up to $maxSizeMb MB.');
  }
  return mimeType;
}

/// Uploads bytes rather than a dart:io File, so browser and native pickers
/// use the same bucket and owner-scoped object paths.
Future<String> uploadPublicMedia({
  required SupabaseClient client,
  required XFile file,
  required String bucket,
  required String ownerId,
  bool isVideo = false,
}) async {
  if (client.auth.currentUser?.id != ownerId) {
    throw FileUploadException(message: 'Log in again before uploading media.');
  }
  final mimeType = await validateMediaFile(file,
      isVideo: isVideo,
      maxSizeMb: bucket == SupabaseConstants.profileImagesBucket ? 5 : 50);
  final extension = path.extension(file.name).toLowerCase();
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final suffix = Random.secure().nextInt(1 << 30).toRadixString(16);
  final objectPath = '$ownerId/${timestamp}_$suffix$extension';
  final storage = client.storage.from(bucket);
  await storage.uploadBinary(
    objectPath,
    await file.readAsBytes(),
    fileOptions: FileOptions(contentType: mimeType),
  );
  return storage.getPublicUrl(objectPath);
}
