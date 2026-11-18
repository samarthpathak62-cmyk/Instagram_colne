import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PostBloc>(
      create: (_) => sl<PostBloc>()..add(LoadPostDetail(postId: postId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: BlocBuilder<PostBloc, PostState>(
          builder: (context, state) {
            if (state is PostDetailLoaded) {
              return ListView(children: [PostCard(post: state.post)]);
            }
            if (state is PostDetailFailure) {
              return Center(child: Text(state.message));
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
