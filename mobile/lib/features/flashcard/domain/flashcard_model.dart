class FlashcardModel {
  final String id;
  final String materialId;
  final String front;
  final String back;
  final bool studied;

  FlashcardModel({
    required this.id,
    required this.materialId,
    required this.front,
    required this.back,
    this.studied = false,
  });

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'] ?? '',
      materialId: json['material_id'] ?? '',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      studied: json['studied'] == true,
    );
  }
}
