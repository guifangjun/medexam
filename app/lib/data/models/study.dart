class StudyPlan {
  final int id;
  final int userId;
  final String title;
  final String planType;
  final List<int> targetChapters;
  final int dailyQuestions;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  StudyPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.planType,
    required this.targetChapters,
    required this.dailyQuestions,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      planType: json['plan_type'] ?? 'daily',
      targetChapters: List<int>.from(json['target_chapters'] ?? []),
      dailyQuestions: json['daily_questions'] ?? 20,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class DailyTask {
  final int id;
  final int? planId;
  final String date;
  final int targetQuestions;
  final int completedQuestions;
  final List<int> targetChapters;
  final bool isCompleted;

  DailyTask({
    required this.id,
    this.planId,
    required this.date,
    required this.targetQuestions,
    required this.completedQuestions,
    required this.targetChapters,
    required this.isCompleted,
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'],
      planId: json['plan_id'],
      date: json['date'],
      targetQuestions: json['target_questions'],
      completedQuestions: json['completed_questions'],
      targetChapters: List<int>.from(json['target_chapters'] ?? []),
      isCompleted: json['is_completed'] ?? false,
    );
  }

  double get progress =>
      targetQuestions > 0 ? completedQuestions / targetQuestions : 0.0;
}

class WrongQuestion {
  final int id;
  final int questionId;
  final String? questionContent;
  final Map<String, String> questionOptions;
  final String? questionAnswer;
  final String? questionExplanation;
  final int? questionDifficulty;
  final List<String> questionTags;
  final String? wrongReason;
  final int reviewCount;
  final bool isMastered;
  final DateTime? nextReviewAt;
  final DateTime createdAt;

  WrongQuestion({
    required this.id,
    required this.questionId,
    this.questionContent,
    this.questionOptions = const {},
    this.questionAnswer,
    this.questionExplanation,
    this.questionDifficulty,
    this.questionTags = const [],
    this.wrongReason,
    required this.reviewCount,
    required this.isMastered,
    this.nextReviewAt,
    required this.createdAt,
  });

  factory WrongQuestion.fromJson(Map<String, dynamic> json) {
    return WrongQuestion(
      id: json['id'],
      questionId: json['question_id'],
      questionContent: json['question_content'],
      questionOptions: Map<String, String>.from(json['question_options'] ?? {}),
      questionAnswer: json['question_answer'],
      questionExplanation: json['question_explanation'],
      questionDifficulty: json['question_difficulty'],
      questionTags: List<String>.from(json['question_tags'] ?? []),
      wrongReason: json['wrong_reason'],
      reviewCount: json['review_count'] ?? 0,
      isMastered: json['is_mastered'] ?? false,
      nextReviewAt: json['next_review_at'] != null
          ? DateTime.parse(json['next_review_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class StudyStats {
  final String date;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final double accuracyRate;
  final int timeSpent;
  final int aiQuestions;

  StudyStats({
    required this.date,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.accuracyRate,
    required this.timeSpent,
    required this.aiQuestions,
  });

  factory StudyStats.fromJson(Map<String, dynamic> json) {
    return StudyStats(
      date: json['date'],
      totalQuestions: json['total_questions'] ?? 0,
      correctCount: json['correct_count'] ?? 0,
      wrongCount: json['wrong_count'] ?? 0,
      accuracyRate: (json['accuracy_rate'] ?? 0.0).toDouble(),
      timeSpent: json['time_spent'] ?? 0,
      aiQuestions: json['ai_questions'] ?? 0,
    );
  }
}

class WeakArea {
  final int chapterId;
  final String chapterName;
  final String examCategory;
  final int practiceCount;
  final int wrongCount;
  final double accuracyRate;
  final String status;

  WeakArea({
    required this.chapterId,
    required this.chapterName,
    required this.examCategory,
    required this.practiceCount,
    required this.wrongCount,
    required this.accuracyRate,
    required this.status,
  });

  factory WeakArea.fromJson(Map<String, dynamic> json) {
    return WeakArea(
      chapterId: json['chapter_id'],
      chapterName: json['chapter_name'] ?? '',
      examCategory: json['exam_category'] ?? '',
      practiceCount: json['practice_count'] ?? 0,
      wrongCount: json['wrong_count'] ?? 0,
      accuracyRate: (json['accuracy_rate'] ?? 0.0).toDouble(),
      status: json['status'] ?? '待开始',
    );
  }
}

class StudyPrescription {
  final String date;
  final int targetQuestions;
  final int completedQuestions;
  final double accuracyRate;
  final int timeSpent;
  final String recommendationTitle;
  final String recommendationReason;
  final String recommendedMode;
  final int? recommendedChapterId;
  final String? recommendedTag;
  final List<WeakArea> weakAreas;

  StudyPrescription({
    required this.date,
    required this.targetQuestions,
    required this.completedQuestions,
    required this.accuracyRate,
    required this.timeSpent,
    required this.recommendationTitle,
    required this.recommendationReason,
    required this.recommendedMode,
    this.recommendedChapterId,
    this.recommendedTag,
    required this.weakAreas,
  });

  factory StudyPrescription.fromJson(Map<String, dynamic> json) {
    return StudyPrescription(
      date: json['date'] ?? '',
      targetQuestions: json['target_questions'] ?? 0,
      completedQuestions: json['completed_questions'] ?? 0,
      accuracyRate: (json['accuracy_rate'] ?? 0.0).toDouble(),
      timeSpent: json['time_spent'] ?? 0,
      recommendationTitle: json['recommendation_title'] ?? '开始今日学习',
      recommendationReason: json['recommendation_reason'] ?? '完成一组练习，积累今日学习数据。',
      recommendedMode: json['recommended_mode'] ?? 'random',
      recommendedChapterId: json['recommended_chapter_id'],
      recommendedTag: json['recommended_tag'],
      weakAreas: (json['weak_areas'] as List? ?? [])
          .map((item) => WeakArea.fromJson(item))
          .toList(),
    );
  }
}

class StatsOverview {
  final int totalQuestions;
  final int totalCorrect;
  final double overallAccuracy;
  final int totalStudyTime;
  final int currentStreak;
  final Map<String, dynamic> subjectStats;

  StatsOverview({
    required this.totalQuestions,
    required this.totalCorrect,
    required this.overallAccuracy,
    required this.totalStudyTime,
    required this.currentStreak,
    required this.subjectStats,
  });

  factory StatsOverview.fromJson(Map<String, dynamic> json) {
    return StatsOverview(
      totalQuestions: json['total_questions'] ?? 0,
      totalCorrect: json['total_correct'] ?? 0,
      overallAccuracy: (json['overall_accuracy'] ?? 0.0).toDouble(),
      totalStudyTime: json['total_study_time'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      subjectStats: json['subject_stats'] ?? {},
    );
  }
}
