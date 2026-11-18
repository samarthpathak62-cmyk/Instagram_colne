part of 'post_bloc.dart';

abstract class PostEvent extends Equatable {
  const PostEvent();

  @override
  List<Object?> get props => [];
}

// Event to trigger creating a new post
class CreateNewPost extends PostEvent {
  final String authorId;
  final PostType type;
  final List<XFile> mediaFiles;
  final String? description;

  const CreateNewPost({
    required this.authorId,
    required this.type,
    required this.mediaFiles,
    this.description,
  });

  @override
  List<Object?> get props => [authorId, type, mediaFiles, description];
}

// Event to load posts for a specific user's profile
class LoadUserPosts extends PostEvent {
  final String userId;
  // Add pagination params later if needed

  const LoadUserPosts({required this.userId});

  @override
  List<Object> get props => [userId];
}

// Event to load post details
class LoadPostDetail extends PostEvent {
  final String postId;
  const LoadPostDetail({required this.postId});
  @override
  List<Object?> get props => [postId];
}
