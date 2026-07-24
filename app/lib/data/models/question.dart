class Question {
  final int id;
  final int chapterId;
  final String questionType; // single/multi/case
  final String content;
  final Map<String, String> options;
  final String answer;
  final String? explanation;
  final int difficulty; // 1-5
  final bool isRealExam;
  final int? examYear;
  final List<String> tags;
  final DateTime createdAt;

  Question({
    required this.id,
    required this.chapterId,
    required this.questionType,
    required this.content,
    required this.options,
    required this.answer,
    this.explanation,
    required this.difficulty,
    required this.isRealExam,
    this.examYear,
    required this.tags,
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      chapterId: json['chapter_id'],
      questionType: json['question_type'] ?? 'single',
      content: json['content'],
      options: Map<String, String>.from(json['options'] ?? {}),
      answer: json['answer'],
      explanation: json['explanation'],
      difficulty: json['difficulty'] ?? 3,
      isRealExam: json['is_real_exam'] ?? false,
      examYear: json['exam_year'],
      tags: List<String>.from(json['知识点'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get optionsText {
    return options.entries.map((e) => '${e.key}. ${e.value}').join('\n');
  }
}

class QuestionSubmit {
  final int questionId;
  final String selectedAnswer;
  final int timeSpent;

  QuestionSubmit({
    required this.questionId,
    required this.selectedAnswer,
    required this.timeSpent,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'selected_answer': selectedAnswer,
      'time_spent': timeSpent,
    };
  }
}

class SubmitResult {
  final bool isCorrect;
  final String correctAnswer;
  final String selectedAnswer; // 用户选择的答案
  final String? explanation;
  final String? wrongReason;

  SubmitResult({
    required this.isCorrect,
    required this.correctAnswer,
    required this.selectedAnswer,
    this.explanation,
    this.wrongReason,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> json) {
    return SubmitResult(
      isCorrect: json['is_correct'],
      correctAnswer: json['correct_answer'],
      selectedAnswer: json['selected_answer'] ?? '',
      explanation: json['explanation'],
      wrongReason: json['wrong_reason'],
    );
  }
}

class ExamQuestionResult {
  final int questionId;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String? explanation;
  final String content;
  final Map<String, String> options;
  final List<String> tags;

  ExamQuestionResult({
    required this.questionId,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    this.explanation,
    required this.content,
    required this.options,
    required this.tags,
  });

  factory ExamQuestionResult.fromJson(Map<String, dynamic> json) {
    return ExamQuestionResult(
      questionId: json['question_id'],
      selectedAnswer: json['selected_answer'],
      correctAnswer: json['correct_answer'],
      isCorrect: json['is_correct'],
      explanation: json['explanation'],
      content: json['content'],
      options: Map<String, String>.from(json['options'] ?? {}),
      tags: List<String>.from(json['知识点'] ?? []),
    );
  }
}

class ExamResult {
  final int totalQuestions;
  final int answeredCount;
  final int unansweredCount;
  final int correctCount;
  final int wrongCount;
  final double score;
  final double accuracyRate;
  final int timeSpent;
  final List<ExamQuestionResult> wrongQuestions;
  final List<ExamQuestionResult> results;

  ExamResult({
    required this.totalQuestions,
    required this.answeredCount,
    required this.unansweredCount,
    required this.correctCount,
    required this.wrongCount,
    required this.score,
    required this.accuracyRate,
    required this.timeSpent,
    required this.wrongQuestions,
    required this.results,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      totalQuestions: json['total_questions'],
      answeredCount: json['answered_count'],
      unansweredCount: json['unanswered_count'],
      correctCount: json['correct_count'],
      wrongCount: json['wrong_count'],
      score: (json['score'] as num).toDouble(),
      accuracyRate: (json['accuracy_rate'] as num).toDouble(),
      timeSpent: json['time_spent'],
      wrongQuestions: (json['wrong_questions'] as List)
          .map((item) => ExamQuestionResult.fromJson(item))
          .toList(),
      results: (json['results'] as List)
          .map((item) => ExamQuestionResult.fromJson(item))
          .toList(),
    );
  }
}
