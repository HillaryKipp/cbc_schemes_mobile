class ReferenceBook {
  final String id;
  final String subjectId;
  final String title; // e.g. "Primary Mathematics Pupils Book 3"
  final String publisher; // e.g. "KLB (Kenya Literature Bureau)", "Oxford", "Longhorn"
  final String? edition;
  final String? authors;

  ReferenceBook({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.publisher,
    this.edition,
    this.authors,
  });

  factory ReferenceBook.fromJson(Map<String, dynamic> json) {
    return ReferenceBook(
      id: json['id'] as String,
      subjectId: json['subject_id'] as String,
      title: json['title'] as String,
      publisher: json['publisher'] as String? ?? 'KLB',
      edition: json['edition'] as String?,
      authors: json['authors'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'title': title,
      'publisher': publisher,
      'edition': edition,
      'authors': authors,
    };
  }

  String get displayName => '$title ($publisher)';
}
