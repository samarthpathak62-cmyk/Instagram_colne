import 'package:image_picker/image_picker.dart' show XFile;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
// For NoParams if needed
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:instagram_clone/features/story/domain/usecases/create_story.dart';
import 'package:instagram_clone/features/story/domain/usecases/get_stories.dart';

part 'story_event.dart';
part 'story_state.dart';

class StoryBloc extends Bloc<StoryEvent, StoryState> {
  final GetStories getStories;
  final CreateStory createStory;

  StoryBloc({required this.getStories, required this.createStory})
      : super(const StoryInitial()) {
    on<LoadStories>(_onLoadStories);
    on<CreateNewStoryItem>(_onCreateNewStoryItem);
  }

  Future<void> _onLoadStories(
      LoadStories event, Emitter<StoryState> emit) async {
    emit(const StoriesLoading());
    final result =
        await getStories(GetStoriesParams(currentUserId: event.currentUserId));
    result.fold(
      (failure) => emit(StoriesLoadFailure(failure.message)),
      (stories) => emit(StoriesLoaded(stories)),
    );
  }

  Future<void> _onCreateNewStoryItem(
      CreateNewStoryItem event, Emitter<StoryState> emit) async {
    emit(const StoryUploadInProgress());
    final result = await createStory.repository.createStoryItem(
      userId: event.userId,
      mediaFile: event.mediaFile,
      mediaType: event.mediaType,
    );
    result.fold(
      (failure) => emit(StoryOperationFailure(failure.message)),
      (_) => emit(const StoryUploadSuccess()),
    );
  }
}
