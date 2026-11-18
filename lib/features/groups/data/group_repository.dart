import 'package:instagram_clone/core/constants/supabase_constants.dart';
import 'package:instagram_clone/features/groups/domain/veyro_group.dart';
import 'package:instagram_clone/features/post/data/models/post_model.dart';
import 'package:instagram_clone/features/post/domain/entities/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupRepository {
  static const pageSize = 20;
  static const _table = 'veyro_groups';
  static const _members = 'veyro_group_members';
  static const _columns =
      'id,owner_id,name,description,category,members:veyro_group_members(count)';
  final SupabaseClient client;

  GroupRepository(this.client);

  String get viewerId =>
      client.auth.currentUser?.id ??
      (throw StateError('Sign in to use groups.'));

  PostgrestFilterBuilder<
      List<
          Map<String, dynamic>>> _groups({bool joined = false}) => client
      .from(_table)
      .select(
          '$_columns,membership:$_members${joined ? '!inner' : ''}(user_id)')
      .eq('membership.user_id', viewerId);

  Future<List<VeyroGroup>> list(
      {required bool joined, String search = '', int offset = 0}) async {
    final query = _groups(joined: joined);
    final term = search
        .trim()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await (term.isEmpty ? query : query.ilike('name', '%$term%'))
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + pageSize - 1);
    return rows.map(VeyroGroup.fromJson).toList();
  }

  Future<VeyroGroup> get(String id) async =>
      VeyroGroup.fromJson(await _groups().eq('id', id).single());

  Map<String, dynamic> _fields(
          String name, String description, GroupCategory category) =>
      {
        'name': name.trim(),
        'description': description.trim(),
        'category': category.name,
      };

  Future<String> create(
      String name, String description, GroupCategory category) async {
    final row = await client
        .from(_table)
        .insert({
          ..._fields(name, description, category),
          'owner_id': viewerId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> edit(String id, String name, String description,
      GroupCategory category) async {
    await client
        .from(_table)
        .update(_fields(name, description, category))
        .eq('id', id)
        .eq('owner_id', viewerId)
        .select('id')
        .single();
  }

  Future<void> join(String id) async {
    await client.from(_members).upsert({'group_id': id, 'user_id': viewerId},
        onConflict: 'group_id,user_id', ignoreDuplicates: true);
  }

  Future<void> leave(String id) async {
    await client
        .from(_members)
        .delete()
        .eq('group_id', id)
        .eq('user_id', viewerId);
  }

  Future<List<Post>> posts(String id, {int offset = 0}) async {
    final viewer = viewerId;
    final rows = await client
        .from(SupabaseConstants.postsTable)
        .select(PostModel.columnsWithViewer)
        .eq('group_id', id)
        .eq('liked_by_user.user_id', viewer)
        .eq('saved_by_user.user_id', viewer)
        .order('created_at', ascending: false, nullsFirst: false)
        .order('id', ascending: false)
        .range(offset, offset + pageSize - 1);
    return rows.map(PostModel.fromJson).toList();
  }
}
