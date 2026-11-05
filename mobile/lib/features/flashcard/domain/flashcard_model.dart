class FlashcardModel {
  final String id;
  final String materialId;
  final String front;
  final String back;
  final int? sourcePage;
  final String? example;
  final bool reviewed;
  // True when the learner marked this card as understood.
  final bool studied;

  FlashcardModel({
    required this.id,
    required this.materialId,
    required this.front,
    required this.back,
    this.sourcePage,
    this.example,
    this.reviewed = false,
    this.studied = false,
  });

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'] ?? '',
      materialId: json['material_id'] ?? '',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      sourcePage: json['source_page'] is int ? json['source_page'] : null,
      example: json['example'] as String?,
      reviewed: json['reviewed'] == true,
      studied: json['studied'] == true,
    );
  }
}
