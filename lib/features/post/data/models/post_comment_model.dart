import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/auth/data/models/user_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post_comment.dart';

class PostCommentModel extends PostComment {
  static const columns = 'id,post_id,user_id,content,created_at,'
      'author:users!comments_user_id_fkey(${SupabaseConstants.publicUserColumns})';

  const PostCommentModel({
    required super.id,
    required super.postId,
    required super.userId,
    required super.content,
    required super.createdAt,
    super.author,
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> row) {
    final author = row['author'] as Map<String, dynamic>?;
    return PostCommentModel(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      userId: row['user_id'] as String,
      content: row['content'] as String,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      author: author == null ? null : UserModel.fromJson(author),
    );
  }
}
