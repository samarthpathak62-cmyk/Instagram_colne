import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart' as di;
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:instagram_clone/features/feed/presentation/bloc/feed_state.dart';
import 'package:instagram_clone/features/story/domain/entities/story.dart';
import 'package:instagram_clone/features/story/presentation/bloc/story_bloc.dart';
import 'package:instagram_clone/features/story/presentation/screens/create_story_screen.dart';
import 'package:instagram_clone/features/story/presentation/screens/story_view_screen.dart';
import 'package:instagram_clone/features/story/presentation/widgets/story_strip.dart';

class FeedStoriesBar extends StatefulWidget {
  final VoidCallback onDiscover;

  const FeedStoriesBar({super.key, required this.onDiscover});

  @override
  State<FeedStoriesBar> createState() => _FeedStoriesBarState();
}

class _FeedStoriesBarState extends State<FeedStoriesBar> {
  final _seenItems = <String>{};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is! Authenticated) return const SizedBox.shrink();
    final userId = auth.user.id;
    return BlocProvider<StoryBloc>(
      create: (_) =>
          di.sl<StoryBloc>()..add(LoadStories(currentUserId: userId)),
      child: BlocListener<FeedCubit, FeedState>(
        listenWhen: (before, after) => after.refreshing && !before.refreshing,
        listener: (context, _) =>
            context.read<StoryBloc>().add(LoadStories(currentUserId: userId)),
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
            return StoryStrip(
              stories: stories,
              ownAvatar: auth.user.profileImageUrl,
              ownName: auth.user.name ?? auth.user.username,
              seenItems: _seenItems,
              onDiscover: state is StoriesLoaded ? widget.onDiscover : null,
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
                if (story.items.isEmpty) return;
                final firstUnseen = story.items
                    .indexWhere((item) => !_seenItems.contains(item.id));
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => StoryViewScreen(
                          story: story,
                          initialIndex: firstUnseen == -1 ? 0 : firstUnseen,
                          onSeen: (id) {
                            if (mounted && !_seenItems.contains(id))
                              setState(() => _seenItems.add(id));
                          },
                        )));
              },
            );
          },
        ),
      ),
    );
  }
}
