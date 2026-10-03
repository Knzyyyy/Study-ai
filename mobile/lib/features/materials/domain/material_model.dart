class MaterialModel {
  final String id;
  final String courseId;
  final String userId;
  final String title;
  final String filePath;
  final String fileType;
  final int? pageCount;
  final String status; // uploaded, processing, done, failed
  final String? errorMessage;
  final DateTime createdAt;

  MaterialModel({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.title,
    required this.filePath,
    required this.fileType,
    this.pageCount,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: json['id'],
      courseId: json['course_id'] as String? ?? '',
      userId: json['user_id'],
      title: json['title'],
      filePath: json['file_path'],
      fileType: json['file_type'],
      pageCount: json['page_count'],
      status: json['status'],
      errorMessage: json['error_message'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
