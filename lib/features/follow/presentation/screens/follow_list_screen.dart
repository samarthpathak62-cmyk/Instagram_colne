import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/error/failures.dart';
import 'package:instagram_clone/features/auth/domain/entities/user.dart';
import 'package:instagram_clone/features/common_widgets/error_widget.dart';
import 'package:instagram_clone/features/common_widgets/user_avatar.dart';
import 'package:instagram_clone/features/follow/domain/repositories/follow_repository.dart';
import 'package:instagram_clone/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:instagram_clone/features/follow/presentation/widgets/follow_button.dart';
import 'package:instagram_clone/features/profile/presentation/screens/profile_screen.dart';

enum FollowListType { followers, following }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final FollowListType initialListType;

  const FollowListScreen(
      {super.key, required this.userId, required this.initialListType});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late FollowListType _type = widget.initialListType;
  late Future<Either<Failure, List<User>>> _request = _fetch();

  Future<Either<Failure, List<User>>> _fetch() {
    final repository = sl<FollowRepository>();
    return _type == FollowListType.followers
        ? repository.getFollowers(widget.userId)
        : repository.getFollowing(widget.userId);
  }

  Future<void> _refresh() async {
    setState(() => _request = _fetch());
    await _request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Connections'), actions: [
          IconButton(
              tooltip: 'Refresh connections',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded))
        ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(spacing: 8, children: [
                        for (final type in FollowListType.values)
                          ChoiceChip(
                            label: Text(type == FollowListType.followers
                                ? 'Followers'
                                : 'Following'),
                            selected: _type == type,
                            onSelected: (_) {
                              if (_type == type) return;
                              setState(() {
                                _type = type;
                                _request = _fetch();
                              });
                            },
                          ),
                      ])),
                  Expanded(
                      child: FutureBuilder<Either<Failure, List<User>>>(
                          future: _request,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done)
                              return const Center(
                                  child: CircularProgressIndicator());
                            return snapshot.data!.fold(
                              (failure) => CustomErrorWidget(
                                  message: failure.message, onRetry: _refresh),
                              (users) => users.isEmpty
                                  ? const Center(
                                      child:
                                          Text('No people in this list yet.'))
                                  : RefreshIndicator(
                                      onRefresh: _refresh,
                                      child: ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        itemCount: users.length,
                                        itemBuilder: (context, index) {
                                          final user = users[index];
                                          return ListTile(
                                            key: ValueKey(user.id),
                                            leading: UserAvatar(
                                                imageUrl:
                                                    user.profilePictureUrl),
                                            title: Text(
                                                '@${user.username ?? 'veyro_user'}'),
                                            onTap: () => Navigator.of(context)
                                                .push(MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        ProfileScreen
                                                            .withProviders(
                                                                user.id))),
                                            trailing: BlocProvider(
                                                create: (_) => sl<FollowBloc>(),
                                                child: FollowButton(
                                                    targetUserId: user.id)),
                                          );
                                        },
                                      )),
                            );
                          })),
                ]))),
      );
}
