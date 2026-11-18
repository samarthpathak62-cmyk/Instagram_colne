import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:instagram_clone/core/di/injection_container.dart';
import 'package:instagram_clone/core/theme/veyro_theme.dart';
import 'package:instagram_clone/features/common_widgets/app_bar.dart';
import 'package:instagram_clone/features/groups/data/group_repository.dart';
import 'package:instagram_clone/features/groups/domain/veyro_group.dart';
import 'package:instagram_clone/features/groups/presentation/group_components.dart';
import 'package:instagram_clone/features/groups/presentation/group_detail_screen.dart';
import 'package:instagram_clone/features/groups/presentation/group_editor.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _search = TextEditingController();
  final _groups = <VeyroGroup>[];
  late final _repository = sl<GroupRepository>();
  Timer? _debounce;
  int _request = 0;
  int _offset = 0;
  bool _joined = false;
  bool _loading = false;
  bool _more = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool next = false, bool clear = false}) async {
    if (next && (_loading || !_more)) return;
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = false;
      if (clear) _groups.clear();
    });
    try {
      final results = await _repository.list(
          joined: _joined, search: _search.text, offset: next ? _offset : 0);
      if (!mounted || id != _request) return;
      setState(() {
        if (!next) {
          _groups.clear();
          _offset = 0;
        }
        final seen = _groups.map((group) => group.id).toSet();
        _groups.addAll(results.where((group) => seen.add(group.id)));
        _offset += results.length;
        _more = results.length == GroupRepository.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted && id == _request)
        setState(() {
          _error = true;
          _loading = false;
        });
    }
  }

  Future<void> _open(String id) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GroupDetailScreen(groupId: id),
    ));
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final id = await showGroupEditor(context, _repository);
    if (mounted && id != null) await _open(id);
  }

  Widget _createButton() => FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded, size: 19),
        label: const Text('New group'),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            CustomAppBar(title: 'Groups', showDefaultActions: false, actions: [
          IconButton(
              tooltip: 'Refresh groups',
              onPressed: () => _load(),
              icon: const Icon(Icons.refresh_rounded)),
        ]),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1010),
          child: RefreshIndicator(
            onRefresh: _load,
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 710;
              return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            wide ? 24 : 12, 16, wide ? 24 : 12, 24),
                        sliver: SliverList.list(children: [
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: EdgeInsets.all(wide ? 19 : 14),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      CircleAvatar(
                                          radius: 22,
                                          backgroundColor: context
                                              .veyroColors.primaryContainer,
                                          foregroundColor: context
                                              .veyroColors.onPrimaryContainer,
                                          child: const Icon(
                                              Icons.groups_outlined,
                                              size: 25)),
                                      const SizedBox(width: 11),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text('Find your groups',
                                                style: context
                                                    .veyroText.titleLarge),
                                            const SizedBox(height: 3),
                                            Text(
                                                'Explore public communities by interest.',
                                                style: context
                                                    .veyroText.bodySmall),
                                          ])),
                                      if (wide) ...[
                                        const SizedBox(width: 12),
                                        _createButton()
                                      ],
                                    ]),
                                    if (!wide) ...[
                                      const SizedBox(height: 12),
                                      _createButton()
                                    ],
                                  ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _search,
                            onChanged: (_) {
                              _debounce?.cancel();
                              _debounce = Timer(
                                  const Duration(milliseconds: 280),
                                  () => _load(clear: true));
                            },
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) {
                              _debounce?.cancel();
                              _load(clear: true);
                            },
                            decoration: InputDecoration(
                              labelText: 'Search groups',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: ValueListenableBuilder(
                                  valueListenable: _search,
                                  builder: (_, value, __) => value.text.isEmpty
                                      ? const SizedBox.shrink()
                                      : IconButton(
                                          tooltip: 'Clear group search',
                                          onPressed: () {
                                            _search.clear();
                                            _debounce?.cancel();
                                            _load(clear: true);
                                          },
                                          icon:
                                              const Icon(Icons.close_rounded))),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, children: [
                            for (final joined in [false, true])
                              ChoiceChip(
                                label: Text(
                                    joined ? 'My groups' : 'Discover groups'),
                                selected: _joined == joined,
                                showCheckmark: false,
                                onSelected: (_) {
                                  if (_joined == joined) return;
                                  _debounce?.cancel();
                                  _joined = joined;
                                  _load(clear: true);
                                },
                              ),
                          ]),
                          const SizedBox(height: 12),
                          if (_loading)
                            const LinearProgressIndicator(minHeight: 2),
                          if (_error)
                            GroupStatusCard(
                                icon: Icons.cloud_off_outlined,
                                title: 'Couldn’t load groups',
                                description:
                                    'Check your connection and try again.',
                                action: TextButton(
                                    onPressed: () => _load(),
                                    child: const Text('Retry')))
                          else if (_groups.isEmpty && !_loading)
                            GroupStatusCard(
                              icon: _search.text.trim().isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.groups_outlined,
                              title: _search.text.trim().isNotEmpty
                                  ? 'No matching groups'
                                  : _joined
                                      ? 'You haven’t joined a group'
                                      : 'Start the first group',
                              description: _search.text.trim().isNotEmpty
                                  ? 'Try a different group name.'
                                  : _joined
                                      ? 'Find a group that shares your interests or create your own.'
                                      : 'Give friends a place to share photos, clips and conversations.',
                            ),
                          if (_groups.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (var i = 0;
                                i < _groups.length;
                                i += wide ? 2 : 1)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var j = i;
                                          j <
                                              math.min(i + (wide ? 2 : 1),
                                                  _groups.length);
                                          j++) ...[
                                        if (j > i) const SizedBox(width: 12),
                                        Expanded(
                                            child: _GroupTile(
                                                group: _groups[j],
                                                onTap: () =>
                                                    _open(_groups[j].id))),
                                      ],
                                      if (wide && i + 1 == _groups.length) ...[
                                        const SizedBox(width: 12),
                                        const Spacer()
                                      ],
                                    ],
                                  )),
                            if (_more && !_loading && !_error)
                              Center(
                                  child: TextButton.icon(
                                      onPressed: () => _load(next: true),
                                      icon:
                                          const Icon(Icons.expand_more_rounded),
                                      label: const Text('Load more groups'))),
                          ],
                        ])),
                  ]);
            }),
          ),
        )),
      );
}

class _GroupTile extends StatelessWidget {
  final VeyroGroup group;
  final VoidCallback onTap;

  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      label:
          'Open ${group.name}, ${group.category.label}, ${groupMemberCount(group.memberCount)}${group.joined ? ', joined' : ''}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GroupArtwork(category: group.category),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.category.label.toUpperCase(),
                              style: context.veyroText.labelSmall?.copyWith(
                                  color: context.veyroColors.primary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(group.name,
                              style: context.veyroText.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (group.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(group.description,
                                style: context.veyroText.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 11),
                          Row(children: [
                            Expanded(
                                child: Text(
                                    '${groupMemberCount(group.memberCount)} · ${group.joined ? 'Joined' : 'Public'}',
                                    style: context.veyroText.labelMedium)),
                            Icon(Icons.arrow_forward_rounded,
                                color: context.veyroColors.primary, size: 18),
                          ]),
                        ],
                      )),
                ])),
      ));
}
