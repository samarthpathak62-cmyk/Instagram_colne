import 'package:flutter/foundation.dart';

class SupabaseConstants {
  // Both Android and Flutter Web use Veyro. This key is public by design;
  // Supabase RLS enforces access to rows and media. Never use a service key here.
  static const supabaseUrl = 'https://klhczdgjewbmwkktmgzp.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_7fxczFSZleFSe85SiDJuSA_YZTs-IcO';

  static const websiteUrl =
      'https://samarthpathak62-cmyk.github.io/Instagram_colne/';
  static const mobileAuthCallback = 'com.instagramcolne.veyro://auth-callback/';

  static String get emailRedirectUrl {
    if (kIsWeb) {
      // Keep the site path (e.g. /Instagram_colne/) for the PKCE callback, but
      // never forward query parameters or a previous auth fragment.
      final page = Uri.base;
      return Uri(
              scheme: page.scheme,
              host: page.host,
              port: page.hasPort ? page.port : null,
              path: page.path)
          .toString();
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return mobileAuthCallback;
    }
    return websiteUrl;
  }

  static const usersTable = 'users';
  static const postsTable = 'posts';
  static const followersTable = 'followers';
  static const savedPostsTable = 'saved_posts';
  static const publicUserColumns = 'id,username,profile_picture_url';

  static const profileImagesBucket = 'profile-images';
  static const postMediaBucket = 'post-media';
  static const storyMediaBucket = 'story-media';
}
