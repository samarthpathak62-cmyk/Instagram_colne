import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final deleted = context
        .select((PostInteractionsCubit cubit) => cubit.forPost(postId).deleted);
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: deleted
          ? const Center(child: Text('This post was deleted.'))
          : BlocProvider<PostBloc>(
              create: (_) =>
                  sl<PostBloc>()..add(LoadPostDetail(postId: postId)),
              child:
                  BlocBuilder<PostBloc, PostState>(builder: (context, state) {
                if (state is PostDetailLoaded) {
                  return Center(
                      child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [PostCard(post: state.post, inDetail: true)]),
                  ));
                }
                if (state is PostDetailFailure) {
                  return CustomErrorWidget(
                    message: 'This post is unavailable or could not be loaded.',
                    onRetry: () => context
                        .read<PostBloc>()
                        .add(LoadPostDetail(postId: postId)),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }),
            ),
    );
  }
}
