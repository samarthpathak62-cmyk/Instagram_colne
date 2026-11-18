/// Tokenize topic labels without treating a URL fragment or a mid-word hash as
/// a topic. The cap bounds the UI for long posts full of tags.
final _hashtag = RegExp(
    r'https?://\S+|(^|[^\p{L}\p{M}\p{N}_/#])#([\p{L}\p{M}\p{N}_]{1,32})(?![\p{L}\p{M}\p{N}_])',
    unicode: true);

List<String> postTopics(String text, {int limit = 6}) => _hashtag
    .allMatches(text)
    .where((match) => match.group(2) != null)
    .map((match) => '#${match.group(2)!.toLowerCase()}')
    .toSet()
    .take(limit)
    .toList(growable: false);
