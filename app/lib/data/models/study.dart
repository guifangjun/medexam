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
  final String date;
  final int targetQuestions;
  final int completedQuestions;
  final List<int> targetChapters;
  final bool isCompleted;

  DailyTask({
    required this.id,
    required this.date,
    required this.targetQuestions,
    required this.completedQuestions,
    required this.targetChapters,
    required this.isCompleted,
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'],
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
  final String? wrongReason;
  final int reviewCount;
  final bool isMastered;
  final DateTime? nextReviewAt;
  final DateTime createdAt;

  WrongQuestion({
    required this.id,
    required this.questionId,
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
