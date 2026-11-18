import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:instagram_clone/features/story/presentation/bloc/story_bloc.dart';
import 'package:instagram_clone/features/story/presentation/screens/create_story_screen.dart';
import 'package:instagram_clone/features/story/presentation/screens/story_view_screen.dart';
import 'package:instagram_clone/features/story/presentation/widgets/story_circles_widget.dart';

class FeedStoriesBar extends StatelessWidget {
  const FeedStoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! Authenticated) return const SizedBox.shrink();
    final userId = auth.user.id;
    return BlocProvider<StoryBloc>(
      create: (_) =>
          di.sl<StoryBloc>()..add(LoadStories(currentUserId: userId)),
      child: BlocConsumer<StoryBloc, StoryState>(
        listener: (context, state) {
          if (state is StoriesLoadFailure) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          final stories =
              state is StoriesLoaded ? state.stories : const <Story>[];
          return StoryCirclesWidget(
            stories: stories,
            onAddStoryTap: () async {
              final created =
                  await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => BlocProvider<StoryBloc>(
                  create: (_) => di.sl<StoryBloc>(),
                  child: const CreateStoryScreen(),
                ),
              ));
              if (created == true && context.mounted) {
                context
                    .read<StoryBloc>()
                    .add(LoadStories(currentUserId: userId));
              }
            },
            onStoryCircleTap: (authorId) {
              final story =
                  stories.firstWhere((story) => story.userId == authorId);
              final pages = story.items
                  .map((item) => Story(
                        id: item.id,
                        userId: story.userId,
                        author: story.author,
                        username: story.username,
                        userProfileImageUrl: story.userProfileImageUrl,
                        items: [item],
                        mediaUrl: item.mediaUrl,
                        mediaType: item.mediaType.name,
                        timestamp: item.createdAt,
                        lastUpdatedAt: item.createdAt,
                      ))
                  .toList();
              if (pages.isEmpty) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => StoryViewScreen(stories: pages),
              ));
            },
          );
        },
      ),
    );
  }
}
