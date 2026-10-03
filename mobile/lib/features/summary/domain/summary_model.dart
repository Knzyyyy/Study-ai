class TermDefinition {
  final String term;
  final String definition;

  TermDefinition({required this.term, required this.definition});

  factory TermDefinition.fromJson(Map<String, dynamic> json) {
    return TermDefinition(
      term: json['term'] ?? '',
      definition: json['definition'] ?? '',
    );
  }
}

class SectionSummary {
  final String title;
  final List<String> keyPoints;
  final List<TermDefinition> keyTerms;
  final List<String> examples;

  SectionSummary({
    required this.title,
    required this.keyPoints,
    required this.keyTerms,
    required this.examples,
  });

  factory SectionSummary.fromJson(Map<String, dynamic> json) {
    return SectionSummary(
      title: json['title'] ?? '',
      keyPoints: List<String>.from(json['key_points'] ?? []),
      keyTerms: (json['key_terms'] as List? ?? [])
          .map((e) => TermDefinition.fromJson(e))
          .toList(),
      examples: List<String>.from(json['examples'] ?? []),
    );
  }
}

class SummaryModel {
  final String id;
  final String materialId;
  final String overview;
  final List<SectionSummary> sections;
  final List<TermDefinition> keyTerms;
  final String modelUsed;

  SummaryModel({
    required this.id,
    required this.materialId,
    required this.overview,
    required this.sections,
    required this.keyTerms,
    required this.modelUsed,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    return SummaryModel(
      id: json['id'],
      materialId: json['material_id'],
      overview: json['overview'] ?? '',
      sections: (json['sections'] as List? ?? [])
          .map((e) => SectionSummary.fromJson(e))
          .toList(),
      keyTerms: (json['key_terms'] as List? ?? [])
          .map((e) => TermDefinition.fromJson(e))
          .toList(),
      modelUsed: json['model_used'] ?? '',
    );
  }
}
