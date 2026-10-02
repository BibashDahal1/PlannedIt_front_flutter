class LegalDocument {
  final String id;
  final String documentType;
  final String version;
  final String title;
  final String content; // Markdown
  final DateTime publishedAt;

  const LegalDocument({
    required this.id,
    required this.documentType,
    required this.version,
    required this.title,
    required this.content,
    required this.publishedAt,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
    id: json['id'] as String,
    documentType: json['document_type'] as String,
    version: json['version'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    publishedAt: DateTime.parse(json['published_at'] as String),
  );
}
