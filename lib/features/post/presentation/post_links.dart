import 'package:flutter/foundation.dart';
import 'package:instagram_clone/core/constants/supabase_constants.dart';

class PostLinks {
  static final _id =
      RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');
  static final _canonical = Uri.parse(SupabaseConstants.websiteUrl);

  static String? read(Uri uri) {
    final id = uri.queryParameters['post'];
    return id != null && _id.hasMatch(id) ? id.toLowerCase() : null;
  }

  static Uri link(String postId, {bool portable = false}) {
    final base = kIsWeb && !portable ? Uri.base : _canonical;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path.isEmpty ? '/' : base.path,
      queryParameters: {'post': postId},
    );
  }

  static String? inMessage(String content) {
    final link = Uri.tryParse(content);
    if (link == null || !link.hasAuthority || link.userInfo.isNotEmpty)
      return null;
    if (link.scheme != 'http' && link.scheme != 'https') return null;
    bool sameSite(Uri other) =>
        link.origin == other.origin && link.path == other.path;
    return sameSite(_canonical) || (kIsWeb && sameSite(Uri.base))
        ? read(link)
        : null;
  }
}
