import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/common_widgets/veyro_empty_state.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/explore/domain/repositories/explore_repository.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_grid_item.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool startWithPeople;
  final String initialQuery;
  final VoidCallback? onGroups;

  const SearchScreen(
      {super.key,
      this.startWithPeople = false,
      this.initialQuery = '',
      this.onGroups});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _limit = 24;
  late final _input = TextEditingController(text: widget.initialQuery);
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
      final auth = context.read<AuthBloc>().state;
      final viewer = auth is Authenticated ? auth.user.id : null;
      final result = await repository.searchUsers(name);
      if (!mounted || id != _request) return;
      setState(() {
        _busy = false;
        result.fold(
            (failure) => _error = failure.message,
            (users) =>
                _users = users.where((user) => user.id != viewer).toList());
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
          if (widget.onGroups != null)
            IconButton(
                tooltip: 'Browse groups',
                onPressed: widget.onGroups,
                icon: const Icon(Icons.groups_outlined)),
          IconButton(
              tooltip: 'Refresh search',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded))
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 896),
                child: Column(children: [
                  if (MediaQuery.sizeOf(context).width >= 800)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 2),
                      child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const VeyroEyebrow('Discovery'),
                                Text('Find something new',
                                    style: context.veyroText.headlineMedium),
                              ])),
                    ),
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
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                    color: context.veyroColors.outlineVariant)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                    color: context.veyroColors.primary)),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _input.clear();
                                  _load();
                                })),
                      )),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(spacing: 8, children: [
                            ChoiceChip(
                                label: const Text('Posts'),
                                showCheckmark: false,
                                selected: !_people,
                                onSelected: (_) => _toggle(false)),
                            ChoiceChip(
                                label: const Text('People'),
                                showCheckmark: false,
                                selected: _people,
                                onSelected: (_) => _toggle(true)),
                          ]))),
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
        return VeyroEmptyState(
            icon: Icons.person_search_outlined,
            title: 'No people found',
            description: _input.text.trim().isEmpty
                ? 'New people will appear here as Veyro grows.'
                : 'Try a different username.');
      final browse = _input.text.trim().isEmpty;
      return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _users.length + (browse ? 1 : 0),
          itemBuilder: (context, index) {
            if (browse && index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Text('Discover people',
                    style: Theme.of(context).textTheme.titleMedium),
              );
            }
            final user = _users[index - (browse ? 1 : 0)];
            return ListTile(
              key: ValueKey(user.id),
              leading: UserAvatar(
                  imageUrl: user.profilePictureUrl,
                  name: user.name ?? user.username),
              title: Text(user.name?.isNotEmpty == true
                  ? user.name!
                  : '@${user.username ?? 'veyro_user'}'),
              subtitle: user.name?.isNotEmpty == true
                  ? Text('@${user.username ?? 'veyro_user'}')
                  : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen.withProviders(user.id))),
            );
          });
    }
    final local = context.watch<PostInteractionsCubit>().state;
    final posts =
        _posts.where((post) => local[post.id]?.deleted != true).toList();
    if (posts.isEmpty && !_more)
      return const VeyroEmptyState(
          icon: Icons.grid_view_rounded,
          title: 'No posts found',
          description:
              'New photos and posts will show up here, or try another search.');
    return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
            builder: (context, constraints) => CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      constraints.maxWidth >= 660 ? 4 : 3,
                                  mainAxisSpacing: 5,
                                  crossAxisSpacing: 5),
                          itemCount: posts.length,
                          itemBuilder: (context, index) => PostGridItem(
                              key: ValueKey(posts[index].id),
                              post: posts[index]),
                        )),
                    if (_busy)
                      const SliverToBoxAdapter(child: LinearProgressIndicator())
                    else if (_more)
                      SliverToBoxAdapter(
                          child: Center(
                              child: TextButton(
                        onPressed: () => _load(append: true),
                        child: Text(_error == null
                            ? 'Load more'
                            : 'Retry loading more posts'),
                      ))),
                  ],
                )));
  }
}
