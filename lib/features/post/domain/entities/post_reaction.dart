enum PostReaction {
  like('Like', '👍'),
  love('Love', '❤️'),
  care('Care', '🤗'),
  laugh('Haha', '😆'),
  wow('Wow', '😮'),
  sad('Sad', '😢');

  final String label;
  final String emoji;
  const PostReaction(this.label, this.emoji);

  static PostReaction parse(Object? value) => values
      .firstWhere((reaction) => reaction.name == value, orElse: () => like);
}
