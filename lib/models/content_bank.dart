class LearningOutcome {
  final String id;
  final String subStrandId;
  final String? referenceBookId;
  final String content;

  LearningOutcome({
    required this.id,
    required this.subStrandId,
    this.referenceBookId,
    required this.content,
  });

  factory LearningOutcome.fromJson(Map<String, dynamic> json) {
    return LearningOutcome(
      id: json['id'] as String,
      subStrandId: json['sub_strand_id'] as String,
      referenceBookId: json['reference_book_id'] as String?,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_strand_id': subStrandId,
      'reference_book_id': referenceBookId,
      'content': content,
    };
  }
}

class KeyInquiryQuestion {
  final String id;
  final String subStrandId;
  final String? referenceBookId;
  final String question;

  KeyInquiryQuestion({
    required this.id,
    required this.subStrandId,
    this.referenceBookId,
    required this.question,
  });

  factory KeyInquiryQuestion.fromJson(Map<String, dynamic> json) {
    return KeyInquiryQuestion(
      id: json['id'] as String,
      subStrandId: json['sub_strand_id'] as String,
      referenceBookId: json['reference_book_id'] as String?,
      question: (json['question'] ?? json['content']) as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_strand_id': subStrandId,
      'reference_book_id': referenceBookId,
      'question': question,
    };
  }
}

class LearningExperience {
  final String id;
  final String subStrandId;
  final String? referenceBookId;
  final String description;

  LearningExperience({
    required this.id,
    required this.subStrandId,
    this.referenceBookId,
    required this.description,
  });

  factory LearningExperience.fromJson(Map<String, dynamic> json) {
    return LearningExperience(
      id: json['id'] as String,
      subStrandId: json['sub_strand_id'] as String,
      referenceBookId: json['reference_book_id'] as String?,
      description: (json['description'] ?? json['content']) as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_strand_id': subStrandId,
      'reference_book_id': referenceBookId,
      'description': description,
    };
  }
}

class LearningResource {
  final String id;
  final String subStrandId;
  final String? referenceBookId;
  final String title;

  LearningResource({
    required this.id,
    required this.subStrandId,
    this.referenceBookId,
    required this.title,
  });

  factory LearningResource.fromJson(Map<String, dynamic> json) {
    return LearningResource(
      id: json['id'] as String,
      subStrandId: json['sub_strand_id'] as String,
      referenceBookId: json['reference_book_id'] as String?,
      title: (json['title'] ?? json['content'] ?? json['resource_name']) as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_strand_id': subStrandId,
      'reference_book_id': referenceBookId,
      'title': title,
    };
  }
}

class AssessmentMethod {
  final String id;
  final String? subStrandId;
  final String name;
  final bool isGlobal;

  AssessmentMethod({
    required this.id,
    this.subStrandId,
    required this.name,
    this.isGlobal = true,
  });

  factory AssessmentMethod.fromJson(Map<String, dynamic> json) {
    return AssessmentMethod(
      id: json['id'] as String,
      subStrandId: json['sub_strand_id'] as String?,
      name: (json['name'] ?? json['content']) as String,
      isGlobal: json['is_global'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sub_strand_id': subStrandId,
      'name': name,
      'is_global': isGlobal,
    };
  }
}
