class Rating {
  final String id;
  final String ratee;
  final int score;
  final String? comment;
  final List<String> tags;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.ratee,
    required this.score,
    this.comment,
    required this.tags,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
    id: json['id'] as String,
    ratee: json['ratee'] as String,
    score: json['score'] as int,
    comment: json['comment'] as String?,
    tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Valid tag values per the API -- keep in sync with the backend's list.
const List<(String value, String label)> ratingTags = [
  ('great_teammate', 'Great teammate'),
  ('late', 'Late'),
  ('no_show', 'No-show'),
  ('unsafe_behavior', 'Unsafe behavior'),
];
