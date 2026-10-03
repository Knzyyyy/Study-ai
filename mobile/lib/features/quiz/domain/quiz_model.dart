class QuizProgressModel {
  final int count;
  final double? latestScore;
  final double? meanScore;
  final double? bestScore;
  final DateTime? lastPracticedAt;

  QuizProgressModel.fromJson(Map<String, dynamic> json)
    : count = (json['count'] as num).toInt(),
      latestScore = (json['latest_score'] as num?)?.toDouble(),
      meanScore = (json['mean_score'] as num?)?.toDouble(),
      bestScore = (json['best_score'] as num?)?.toDouble(),
      lastPracticedAt = DateTime.tryParse(
        json['last_practiced_at'] as String? ?? '',
      )?.toLocal();

  String get summary {
    if (count == 0) return 'Belum latihan';
    final date = lastPracticedAt;
    final formattedDate = date == null
        ? 'Tanggal tidak tersedia'
        : '${date.day}/${date.month}/${date.year}';
    return 'Indikator pemahaman (rata-rata): ${meanScore?.toStringAsFixed(1) ?? "—"}%\n'
        'Terbaru: ${latestScore?.toStringAsFixed(1) ?? "Tidak diketahui"} • '
        'Terbaik: ${bestScore?.toStringAsFixed(1) ?? "—"}\n'
        '$count latihan • Terakhir tercatat: $formattedDate';
  }
}

class QuizQuestionModel {
  final String id;
  final String question;
  final List<String> options;

  QuizQuestionModel({
    required this.id,
    required this.question,
    required this.options,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      // Parsing jsonb array ke List<String>
      options: List<String>.from(json['options'] ?? []),
    );
  }
}

class QuizAttemptModel {
  final String id;
  final String title;
  final int score;
  final DateTime? createdAt;

  QuizAttemptModel.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      score = (json['score'] as num).toInt(),
      createdAt = json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String).toLocal();
}

class QuizReviewQuestionModel {
  final QuizQuestionModel question;
  final int? selectedIndex;
  final int correctIndex;
  final String explanation;

  QuizReviewQuestionModel.fromJson(Map<String, dynamic> json)
    : question = QuizQuestionModel.fromJson(json),
      selectedIndex = json['selected_index'] as int?,
      correctIndex = json['correct_index'] as int,
      explanation = json['explanation'] as String;

  String get chosenOption {
    final index = selectedIndex;
    return index == null || index < 0 || index >= question.options.length
        ? 'Tidak dijawab'
        : question.options[index];
  }
}

class QuizReviewModel {
  final QuizAttemptModel attempt;
  final List<QuizReviewQuestionModel> questions;

  QuizReviewModel.fromJson(Map<String, dynamic> json)
    : attempt = QuizAttemptModel.fromJson(json['attempt']),
      questions = (json['questions'] as List)
          .map((item) => QuizReviewQuestionModel.fromJson(item))
          .toList();
}

class QuizDataModel {
  final String quizId;
  final String title;
  final List<QuizQuestionModel> questions;

  QuizDataModel({
    required this.quizId,
    required this.title,
    required this.questions,
  });
}
