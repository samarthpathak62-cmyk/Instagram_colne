import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/chat/domain/usecases/get_or_create_chat.dart';
import 'package:instagram_clone/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:instagram_clone/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:instagram_clone/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:instagram_clone/features/follow/presentation/widgets/follow_button.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_bloc.dart';
import 'package:instagram_clone/features/profile/presentation/widgets/profile_posts_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:instagram_clone/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:instagram_clone/features/profile/presentation/screens/edit_profile_screen.dart'; // To be created
import 'package:instagram_clone/features/settings/presentation/screens/settings_screen.dart';
import 'package:instagram_clone/features/common_widgets/app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For network images

class ProfileScreen extends StatefulWidget {
  final String userId; // ID of the profile to display

  const ProfileScreen({required this.userId, super.key});

  static Widget withProviders(String userId) => MultiBlocProvider(
        providers: [
          BlocProvider<ProfileBloc>(create: (_) => sl<ProfileBloc>()),
          BlocProvider<PostBloc>(
              create: (_) =>
                  sl<PostBloc>()..add(LoadUserPosts(userId: userId))),
        ],
        child: ProfileScreen(userId: userId),
      );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load the profile when the screen initializes
    context.read<ProfileBloc>().add(LoadProfile(userId: widget.userId));
  }

  bool _openingChat = false;

  Future<void> _openChat(User viewer) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    final result = await sl<GetOrCreateChat>()(GetOrCreateChatParams(
      currentUserId: viewer.id,
      otherUserId: widget.userId,
    ));
    if (!mounted) return;
    setState(() => _openingChat = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (chat) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BlocProvider<ChatBloc>(
          create: (_) => sl<ChatBloc>(),
          child: ChatDetailScreen(chat: chat, currentUser: viewer),
        ),
      )),
    );
  }

  void _editProfile() {
    final bloc = context.read<ProfileBloc>();
    final state = bloc.state;
    if (state is! ProfileLoaded) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: EditProfileScreen(currentProfile: state.profile),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final viewer = auth is Authenticated ? auth.user : null;
    final isOwnProfile = viewer?.id == widget.userId;
    final profileState = context.watch<ProfileBloc>().state;

    return Scaffold(
      appBar: CustomAppBar(
        title: profileState is ProfileLoaded
            ? profileState.profile.username
            : 'Profile',
        actions: [
          if (isOwnProfile)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editProfile,
            ),
          if (isOwnProfile)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(userId: widget.userId),
                  ),
                );
              },
            ),
          if (isOwnProfile)
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
        ],
        showDefaultActions: false,
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ProfileLoaded) {
            final profile = state.profile;
            return RefreshIndicator(
              onRefresh: () async {
                final profileBloc = context.read<ProfileBloc>();
                final postsBloc = context.read<PostBloc>();
                profileBloc.add(LoadProfile(userId: widget.userId));
                postsBloc.add(LoadUserPosts(userId: widget.userId));
                await profileBloc.stream
                    .firstWhere((state) => state is! ProfileLoading);
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: profile.profileImageUrl != null
                              ? CachedNetworkImageProvider(
                                  profile.profileImageUrl!)
                              : null,
                          child: profile.profileImageUrl == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('Posts', profile.postCount),
                              _buildStatColumn(
                                  'Followers', profile.followerCount),
                              _buildStatColumn(
                                  'Following', profile.followingCount),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.fullName != null &&
                            profile.fullName!.isNotEmpty)
                          Text(profile.fullName!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        if (profile.bio != null && profile.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(profile.bio!),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      children: [
                        if (isOwnProfile)
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: _editProfile,
                                  child: const Text('Edit Profile'))),
                        if (!isOwnProfile && viewer != null) ...[
                          Expanded(
                              child: BlocProvider<FollowBloc>(
                            create: (_) => sl<FollowBloc>(),
                            child: FollowButton(targetUserId: widget.userId),
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                              child: OutlinedButton(
                            onPressed:
                                _openingChat ? null : () => _openChat(viewer),
                            child: const Text('Message'),
                          )),
                        ],
                      ],
                    ),
                  ),
                  // تبويبات (شبكة، فيديو، إلخ)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        Icon(Icons.grid_on, size: 28),
                        Icon(Icons.video_collection_outlined, size: 28),
                        Icon(Icons.person_pin_outlined, size: 28),
                      ],
                    ),
                  ),
                  Expanded(child: BlocBuilder<PostBloc, PostState>(
                    builder: (context, state) {
                      if (state is PostsLoaded)
                        return ProfilePostsGrid(posts: state.posts);
                      if (state is PostsLoadFailure)
                        return Center(child: Text(state.message));
                      return const Center(child: CircularProgressIndicator());
                    },
                  )),
                ],
              ),
            );
          } else if (state is ProfileError) {
            return Center(
                child: Text('Failed to load profile: ${state.message}'));
          } else {
            return const Center(child: Text('Loading profile...'));
          }
        },
      ),
    );
  }

  Column _buildStatColumn(String label, int number) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          number.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: context.veyroText.bodySmall?.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
