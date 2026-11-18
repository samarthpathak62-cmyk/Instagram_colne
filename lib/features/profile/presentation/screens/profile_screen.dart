import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_or_create_chat.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:instagram_clone/features/common_widgets/app_bar.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/common_widgets/veyro_brand.dart';
import 'package:instagram_clone/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:instagram_clone/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:instagram_clone/features/follow/presentation/screens/follow_list_screen.dart';
import 'package:instagram_clone/features/follow/presentation/widgets/follow_button.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_grid_item.dart';
import 'package:instagram_clone/features/profile/domain/entities/profile.dart';
import 'package:instagram_clone/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:instagram_clone/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:instagram_clone/features/settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({required this.userId, super.key});

  static Widget withProviders(String userId) => MultiBlocProvider(
        providers: [
          BlocProvider(
              create: (_) =>
                  sl<ProfileBloc>()..add(LoadProfile(userId: userId))),
          BlocProvider(
              create: (_) =>
                  sl<PostBloc>()..add(LoadUserPosts(userId: userId))),
        ],
        child: ProfileScreen(userId: userId),
      );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _openingChat = false;
  PostType? _filter;

  Future<void> _openChat(User viewer) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    final result = await sl<GetOrCreateChat>()(GetOrCreateChatParams(
        currentUserId: viewer.id, otherUserId: widget.userId));
    if (!mounted) return;
    setState(() => _openingChat = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (chat) => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
                create: (_) => sl<ChatBloc>(),
                child: ChatDetailScreen(chat: chat, currentUser: viewer),
              ))),
    );
  }

  void _editProfile() {
    final bloc = context.read<ProfileBloc>();
    final state = bloc.state;
    if (state is! ProfileLoaded) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
              value: bloc,
              child: EditProfileScreen(currentProfile: state.profile),
            )));
  }

  void _reloadProfile() =>
      context.read<ProfileBloc>().add(LoadProfile(userId: widget.userId));
  void _reloadPosts() =>
      context.read<PostBloc>().add(LoadUserPosts(userId: widget.userId));

  Future<void> _refresh() async {
    final result = context
        .read<ProfileBloc>()
        .stream
        .firstWhere((state) => state is ProfileLoaded || state is ProfileError);
    _reloadPosts();
    _reloadProfile();
    await result;
  }

  Future<void> _connections(FollowListType type) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            FollowListScreen(userId: widget.userId, initialListType: type)));
    if (mounted) _reloadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final viewer = auth is Authenticated ? auth.user : null;
    final isOwn = viewer?.id == widget.userId;
    final state = context.watch<ProfileBloc>().state;
    return Scaffold(
      appBar: CustomAppBar(
        title:
            state is ProfileLoaded ? '@${state.profile.username}' : 'Profile',
        showDefaultActions: false,
        actions: [
          IconButton(
              tooltip: 'Refresh profile',
              onPressed: state is ProfileLoading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded)),
          if (isOwn) ...[
            IconButton(
              tooltip: 'Saved posts',
              icon: const Icon(Icons.bookmark_outline_rounded),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => FavoritesScreen(userId: widget.userId))),
            ),
            IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            SettingsScreen(userId: widget.userId)))),
            IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () =>
                    context.read<AuthBloc>().add(AuthLogoutRequested())),
          ],
        ],
      ),
      body: state is ProfileLoaded && viewer != null
          ? Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: _body(state.profile, viewer, isOwn)))
          : state is ProfileError
              ? CustomErrorWidget(
                  message: state.message, onRetry: _reloadProfile)
              : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _body(Profile profile, User viewer, bool isOwn) {
    final postsState = context.watch<PostBloc>().state;
    final local = context.watch<PostInteractionsCubit>().state;
    final all = postsState is PostsLoaded
        ? postsState.posts
            .where((post) => local[post.id]?.deleted != true)
            .toList()
        : const <Post>[];
    final posts = _filter == null
        ? all
        : all.where((post) => post.type == _filter).toList();
    return RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: _profileHeader(profile, viewer, isOwn,
                  postsState is PostsLoaded ? all.length : profile.postCount),
            )),
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(spacing: 8, runSpacing: 5, children: [
                      for (final option in [
                        null,
                        PostType.image,
                        PostType.video,
                        PostType.text
                      ])
                        ChoiceChip(
                            selected: _filter == option,
                            onSelected: (_) => setState(() => _filter = option),
                            label: Text(switch (option) {
                              null => 'All posts',
                              PostType.image => 'Photos',
                              PostType.video => 'Reels',
                              PostType.text => 'Text',
                            })),
                    ]))),
            if (postsState is PostsLoaded && posts.isNotEmpty)
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 188,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => PostGridItem(
                        key: ValueKey(posts[index].id), post: posts[index]),
                  ))
            else
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: postsState is PostsLoadFailure
                    ? CustomErrorWidget(
                        message: postsState.message, onRetry: _reloadPosts)
                    : postsState is PostsLoaded
                        ? const Center(
                            child: Text('No posts to show here yet.'))
                        : const Center(child: CircularProgressIndicator()),
              )),
          ],
        ));
  }

  Widget _profileHeader(
      Profile profile, User viewer, bool isOwn, int postsCount) {
    final colors = context.veyroColors;
    final name = profile.fullName?.trim();
    final label = name?.isNotEmpty == true ? name! : profile.username;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 130,
            child: Stack(children: [
              PositionedDirectional(
                start: 0,
                end: 0,
                top: 0,
                height: 102,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                      colors: [
                        colors.primaryContainer,
                        colors.surfaceContainerHigh
                      ],
                      begin: AlignmentDirectional.bottomStart,
                      end: AlignmentDirectional.topEnd,
                    )),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 22),
                          child: const VeyroMark(size: 84)),
                    )),
              ),
              PositionedDirectional(
                  start: 16,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surfaceContainerLow),
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: UserAvatar(
                            name: label,
                            imageUrl: profile.profileImageUrl,
                            radius: 34)),
                  )),
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(17, 6, 17, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.veyroText.headlineMedium),
                Text('@${profile.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.veyroText.bodySmall),
                if (profile.bio?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 9),
                  Text(profile.bio!)
                ],
                const SizedBox(height: 6),
                Wrap(
                    spacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                          padding: const EdgeInsetsDirectional.only(end: 5),
                          child: Text('$postsCount posts',
                              style: context.veyroText.labelLarge)),
                      TextButton(
                          onPressed: () =>
                              _connections(FollowListType.followers),
                          child: Text('${profile.followerCount} followers')),
                      TextButton(
                          onPressed: () =>
                              _connections(FollowListType.following),
                          child: Text('${profile.followingCount} following')),
                    ]),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (isOwn)
                    OutlinedButton.icon(
                        onPressed: _editProfile,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Profile'))
                  else ...[
                    BlocProvider(
                        create: (_) => sl<FollowBloc>(),
                        child: FollowButton(
                            targetUserId: widget.userId,
                            onChanged: _reloadProfile)),
                    OutlinedButton.icon(
                        onPressed:
                            _openingChat ? null : () => _openChat(viewer),
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        label: const Text('Message')),
                  ],
                ]),
              ],
            )),
      ]),
    );
  }
}
