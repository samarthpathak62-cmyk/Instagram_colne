import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/explore/domain/repositories/explore_repository.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_grid_item.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool startWithPeople;

  const SearchScreen({super.key, this.startWithPeople = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _limit = 24;
  final _input = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  int _offset = 0;
  late bool _people = widget.startWithPeople;
  bool _busy = true;
  bool _more = false;
  String? _error;
  List<Post> _posts = const [];
  List<User> _users = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _queue() {
    _request++;
    _debounce?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _posts = const [];
      _users = const [];
    });
    _debounce = Timer(const Duration(milliseconds: 270), _load);
  }

  Future<void> _load({bool append = false}) async {
    _debounce?.cancel();
    final id = ++_request;
    final repository = sl<ExploreRepository>();
    final query = _input.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      if (!append) {
        _offset = 0;
        _more = false;
        _posts = const [];
        _users = const [];
      }
    });
    if (_people) {
      final name = query.replaceFirst(RegExp(r'^@'), '');
      if (name.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final result = await repository.searchUsers(name);
      if (!mounted || id != _request) return;
      setState(() {
        _busy = false;
        result.fold(
            (failure) => _error = failure.message, (users) => _users = users);
      });
    } else {
      final result = await repository.getExplorePosts(
          limit: _limit, offset: _offset, query: query);
      if (!mounted || id != _request) return;
      setState(() {
        _busy = false;
        result.fold((failure) => _error = failure.message, (posts) {
          final seen = _posts.map((post) => post.id).toSet();
          _posts = [..._posts, ...posts.where((post) => seen.add(post.id))];
          _offset += posts.length;
          _more = posts.length == _limit;
        });
      });
    }
  }

  void _toggle(bool people) {
    if (_people == people) return;
    setState(() => _people = people);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Explore'), actions: [
          IconButton(
              tooltip: 'Refresh search',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded))
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: TextField(
                        controller: _input,
                        maxLength: 80,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => _queue(),
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                            labelText:
                                _people ? 'Search by username' : 'Search posts',
                            counterText: '',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _input.clear();
                                  _load();
                                })),
                      )),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                        label: const Text('Posts'),
                        selected: !_people,
                        onSelected: (_) => _toggle(false)),
                    ChoiceChip(
                        label: const Text('People'),
                        selected: _people,
                        onSelected: (_) => _toggle(true)),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(child: _results(context)),
                ]))),
      );

  Widget _results(BuildContext context) {
    if (_error != null && _posts.isEmpty)
      return CustomErrorWidget(message: _error!, onRetry: _load);
    if (_busy && _posts.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (_people) {
      if (_users.isEmpty)
        return Center(
            child: Text(_input.text.trim().isEmpty
                ? 'Search for a username.'
                : 'No people found.'));
      return ListView.builder(
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return ListTile(
              key: ValueKey(user.id),
              leading: UserAvatar(imageUrl: user.profilePictureUrl),
              title: Text('@${user.username ?? 'veyro_user'}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen.withProviders(user.id))),
            );
          });
    }
    final local = context.watch<PostInteractionsCubit>().state;
    final posts =
        _posts.where((post) => local[post.id]?.deleted != true).toList();
    if (posts.isEmpty && !_more)
      return const Center(child: Text('No posts found.'));
    return RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => PostGridItem(
                      key: ValueKey(posts[index].id), post: posts[index]),
                )),
            if (_busy)
              const SliverToBoxAdapter(child: LinearProgressIndicator())
            else if (_more)
              SliverToBoxAdapter(
                  child: Center(
                      child: TextButton(
                onPressed: () => _load(append: true),
                child: Text(
                    _error == null ? 'Load more' : 'Retry loading more posts'),
              ))),
          ],
        ));
  }
}
