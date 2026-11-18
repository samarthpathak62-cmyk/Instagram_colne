import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/favorites/domain/entities/favorite.dart';
import 'package:instagram_clone/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_grid_item.dart';

class FavoritesScreen extends StatefulWidget {
  final String userId;

  const FavoritesScreen({super.key, required this.userId});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Favorite> _saved = const [];
  bool _busy = false;
  bool _newestFirst = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await sl<FavoriteRepository>().getFavorites(widget.userId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold(
          (failure) => _error = failure.message, (saved) => _saved = saved);
    });
  }

  Future<void> _remove(Favorite item) async {
    final actions = context.read<PostInteractionsCubit>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Remove from saved?'),
              content: const Text('This won’t remove the original post.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Remove')),
              ],
            ));
    if (!mounted || confirmed != true || item.post == null) return;
    final error = await actions.setSaved(item.post!, false);
    if (!mounted) return;
    if (error != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final local = context.watch<PostInteractionsCubit>().state;
    final posts = _saved
        .where((row) =>
            row.post != null &&
            local[row.postId]?.deleted != true &&
            local[row.postId]?.saved != false)
        .toList();
    posts.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Saved posts'), actions: [
        IconButton(
            tooltip: 'Refresh saved posts',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded)),
        PopupMenuButton<bool>(
          tooltip: 'Sort saved posts',
          icon: const Icon(Icons.sort_rounded),
          initialValue: _newestFirst,
          onSelected: (value) => setState(() => _newestFirst = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: true, child: Text('Newest saves first')),
            PopupMenuItem(value: false, child: Text('Oldest saves first'))
          ],
        ),
      ]),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: _busy && posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? CustomErrorWidget(message: _error!, onRetry: _load)
                : posts.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                                'Save posts from Home or Reels to see them here.',
                                textAlign: TextAlign.center)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: posts.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 190,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8),
                          itemBuilder: (context, index) => PostGridItem(
                            key: ValueKey(posts[index].postId),
                            post: posts[index].post!,
                            trailing: IconButton.filledTonal(
                                tooltip: 'Remove from saved',
                                icon: const Icon(Icons.bookmark_remove_outlined,
                                    size: 19),
                                onPressed: () => _remove(posts[index])),
                          ),
                        )),
      )),
    );
  }
}
