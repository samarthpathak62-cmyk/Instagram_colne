enum GroupCategory {
  general('General'),
  creative('Art & photography'),
  local('Local community'),
  gaming('Gaming'),
  learning('Learning');

  final String label;
  const GroupCategory(this.label);

  static GroupCategory parse(Object? value) => values
      .firstWhere((category) => category.name == value, orElse: () => general);
}

class VeyroGroup {
  final String id;
  final String? ownerId;
  final String name;
  final String description;
  final GroupCategory category;
  final int memberCount;
  final bool joined;

  const VeyroGroup(
      {required this.id,
      this.ownerId,
      required this.name,
      required this.description,
      required this.category,
      required this.memberCount,
      required this.joined});

  factory VeyroGroup.fromJson(Map<String, dynamic> row) {
    final members = (row['members'] as List?)?.firstOrNull;
    final count = members is Map ? members['count'] : null;
    return VeyroGroup(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String?,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      category: GroupCategory.parse(row['category']),
      memberCount: int.tryParse('$count') ?? 0,
      joined: (row['membership'] as List?)?.isNotEmpty ?? false,
    );
  }
}
