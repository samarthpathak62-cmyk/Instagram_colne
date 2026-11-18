import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/app_bar.dart';
import 'package:instagram_clone/features/groups/data/group_repository.dart';
import 'package:instagram_clone/features/groups/domain/veyro_group.dart';
import 'package:instagram_clone/features/groups/presentation/group_components.dart';
import 'package:instagram_clone/features/groups/presentation/group_editor.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:instagram_clone/features/post/presentation/bloc/post_interactions_cubit.dart';
import 'package:instagram_clone/features/post/presentation/screens/create_post_screen.dart';
import 'package:instagram_clone/features/post/presentation/widgets/post_card.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final _repository = sl<GroupRepository>();
  final _posts = <Post>[];
  VeyroGroup? _group;
  int _offset = 0;
  bool _loading = false;
  bool _membershipBusy = false;
  bool _more = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (_loading || (next && !_more)) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final info = next ? _group : await _repository.get(widget.groupId);
      if (mounted && !next) setState(() => _group = info);
      final results =
          await _repository.posts(widget.groupId, offset: next ? _offset : 0);
      if (!mounted) return;
      setState(() {
        if (!next) {
          _posts.clear();
          _offset = 0;
        }
        final seen = _posts.map((post) => post.id).toSet();
        _posts.addAll(results.where((post) => seen.add(post.id)));
        _offset += results.length;
        _more = results.length == GroupRepository.pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _membership(VeyroGroup group) async {
    if (_membershipBusy || _loading) return;
    setState(() => _membershipBusy = true);
    try {
      if (group.joined) {
        final leave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Leave this group?'),
                  content: const Text(
                      'Your existing posts will stay in this public group. You can rejoin anytime.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Leave group'))
                  ],
                ));
        if (leave != true || !mounted) return;
        await _repository.leave(group.id);
      } else {
        await _repository.join(group.id);
      }
      if (mounted) await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update membership. Please try again.')));
    } finally {
      if (mounted) setState(() => _membershipBusy = false);
    }
  }

  Future<void> _compose(VeyroGroup group) async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (context) => CreatePostScreen(
          groupId: group.id,
          groupName: group.name,
          onCreated: (_) => Navigator.of(context).pop(true)),
    ));
    if (created == true && mounted) await _load();
  }

  Future<void> _edit(VeyroGroup group) async {
    final id = await showGroupEditor(context, _repository, group: group);
    if (id != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final local = context.watch<PostInteractionsCubit>();
    final posts =
        _posts.where((post) => !local.forPost(post.id).deleted).toList();
    return Scaffold(
      appBar: CustomAppBar(
          title: group?.name ?? 'Group',
          showDefaultActions: false,
          actions: [
            IconButton(
                tooltip: 'Refresh group',
                onPressed: _loading || _membershipBusy ? null : () => _load(),
                icon: const Icon(Icons.refresh_rounded)),
          ]),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 708),
        child: RefreshIndicator(
          onRefresh: () => _membershipBusy ? Future.value() : _load(),
          child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                    sliver: SliverMainAxisGroup(slivers: [
                      SliverToBoxAdapter(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            if (group != null) ...[
                              _cover(group),
                              const SizedBox(height: 18),
                              Text('Discussion',
                                  style: context.veyroText.titleLarge),
                              const SizedBox(height: 8),
                              if (group.joined)
                                Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FilledButton.icon(
                                        onPressed: _membershipBusy || _loading
                                            ? null
                                            : () => _compose(group),
                                        icon: const Icon(Icons.edit_square,
                                            size: 18),
                                        label: const Text('Write a post')))
                              else
                                Text('Join this group to share a post.',
                                    style: context.veyroText.bodySmall),
                              const SizedBox(height: 12),
                            ],
                            if (_loading)
                              const LinearProgressIndicator(minHeight: 2),
                            if (_error)
                              GroupStatusCard(
                                  icon: Icons.cloud_off_outlined,
                                  title: group == null
                                      ? 'Couldn’t open this group'
                                      : 'Couldn’t load the discussion',
                                  description:
                                      'It may be unavailable, or your connection may have dropped.',
                                  action: TextButton(
                                      onPressed: _membershipBusy
                                          ? null
                                          : () => _load(),
                                      child: const Text('Retry')))
                            else if (group != null &&
                                posts.isEmpty &&
                                !_loading)
                              const GroupStatusCard(
                                  icon: Icons.forum_outlined,
                                  title: 'No posts yet',
                                  description:
                                      'Group updates, photos and videos will appear here.'),
                          ])),
                      SliverList.builder(
                          itemCount: posts.length,
                          itemBuilder: (context, index) => PostCard(
                                key: ValueKey(posts[index].id),
                                post: posts[index],
                                showGroupOrigin: false,
                                canModerate: group?.ownerId == local.userId,
                              )),
                      if (_more && !_loading && !_error)
                        SliverToBoxAdapter(
                            child: Center(
                                child: TextButton.icon(
                          onPressed:
                              _membershipBusy ? null : () => _load(next: true),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('More group posts'),
                        ))),
                    ])),
              ]),
        ),
      )),
    );
  }

  Widget _cover(VeyroGroup group) {
    final owner = group.ownerId == _repository.viewerId;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GroupArtwork(category: group.category, height: 115),
        Padding(
          padding: const EdgeInsets.all(19),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PUBLIC GROUP  /  ${group.category.label.toUpperCase()}',
                style: context.veyroText.labelSmall?.copyWith(
                    color: context.veyroColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
            const SizedBox(height: 5),
            Text(group.name, style: context.veyroText.headlineMedium),
            if (group.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(group.description,
                  style: context.veyroText.bodyMedium?.copyWith(height: 1.5)),
            ],
            const SizedBox(height: 14),
            Wrap(
                spacing: 10,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                      '${groupMemberCount(group.memberCount)}${owner ? ' · Admin' : group.joined ? ' · Joined' : ''}',
                      style: context.veyroText.labelLarge),
                  if (owner)
                    OutlinedButton.icon(
                        onPressed: _loading ? null : () => _edit(group),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Edit group'))
                  else if (group.joined)
                    OutlinedButton(
                        onPressed: _membershipBusy || _loading
                            ? null
                            : () => _membership(group),
                        child: const Text('Leave group'))
                  else
                    FilledButton.icon(
                        onPressed: _membershipBusy || _loading
                            ? null
                            : () => _membership(group),
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 18),
                        label: const Text('Join group')),
                ]),
          ]),
        ),
      ]),
    );
  }
}
