import 'package:instagram_clone/features/auth/domain/entities/user.dart';

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final User? author;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.author,
  });
}

class CommentPage {
  static const size = 25;
  static const maxLength = 1000;

  final List<PostComment> comments;
  final int total;

  const CommentPage(this.comments, this.total);
}
