import 'package:image_picker/image_picker.dart' show XFile;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/domain/usecases/create_post.dart';
import 'package:instagram_clone/features/post/domain/usecases/get_user_posts.dart';
import 'package:instagram_clone/features/post/domain/usecases/get_post.dart';

part 'post_event.dart';
part 'post_state.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  final CreatePost createPost;
  final GetUserPosts getUserPosts;
  final GetPost getPost;

  PostBloc({
    required this.createPost,
    required this.getUserPosts,
    required this.getPost,
  }) : super(PostInitial()) {
    on<CreateNewPost>(_onCreateNewPost);
    on<LoadUserPosts>(_onLoadUserPosts);
    on<LoadPostDetail>(_onLoadPostDetail);
  }

  Future<void> _onCreateNewPost(
      CreateNewPost event, Emitter<PostState> emit) async {
    emit(PostUploading());
    final result = await createPost(CreatePostParams(
      authorId: event.authorId,
      type: event.type,
      mediaFiles: event.mediaFiles,
      description: event.description,
    ));
    result.fold(
      (failure) =>
          emit(PostOperationFailure(failure.message)), // Use failure.message
      (post) =>
          emit(PostUploadSuccess(post)), // Emit success state with the new post
    );
  }

  Future<void> _onLoadUserPosts(
      LoadUserPosts event, Emitter<PostState> emit) async {
    emit(PostsLoading());
    final result = await getUserPosts(GetUserPostsParams(userId: event.userId));
    result.fold(
      (failure) =>
          emit(PostsLoadFailure(failure.message)), // Use failure.message
      (posts) => emit(PostsLoaded(posts)), // Reuse PostsLoaded state
    );
  }

  Future<void> _onLoadPostDetail(
      LoadPostDetail event, Emitter<PostState> emit) async {
    emit(PostsLoading());
    final result = await getPost(GetPostParams(postId: event.postId));
    result.fold((failure) => emit(PostDetailFailure(failure.message)),
        (post) => emit(PostDetailLoaded(post)));
  }
}
