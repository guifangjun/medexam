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
  final String examCategory;
  final String date;
  final int targetQuestions;
  final int completedQuestions;
  final List<int> targetChapters;
  final bool isCompleted;

  DailyTask({
    required this.id,
    this.planId,
    required this.examCategory,
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
      examCategory: json['exam_category'] ?? '执业资格',
      date: json['date'],
      targetQuestions: json['target_questions'],
      completedQuestions: json['completed_questions'],
      targetChapters: List<int>.from(json['target_chapters'] ?? []),
      isCompleted: json['is_completed'] ?? false,
    );
  }

  double get progress =>
      targetQuestions > 0 ? completedQuestions / targetQuestions : 0.0;

  double get displayProgress => progress.clamp(0.0, 1.0);

  int get displayPercent => (displayProgress * 100).round();

  int get remainingQuestions =>
      (targetQuestions - completedQuestions).clamp(0, targetQuestions);

  bool get isOverTarget =>
      targetQuestions > 0 && completedQuestions > targetQuestions;

  String get progressLabel {
    if (targetQuestions <= 0) return '已完成 $completedQuestions 题';
    if (isOverTarget) {
      return '目标 $targetQuestions 题，已完成 $completedQuestions 题';
    }
    return '$completedQuestions/$targetQuestions 题';
  }

  String get completionStatusLabel {
    if (isOverTarget) return '今日已超额完成 🎉';
    return isCompleted ? '今日任务已完成 🎉' : '继续加油！';
  }
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

  String get chapterName =>
      questionTags.isNotEmpty ? questionTags.first : '未关联章节';

  String get masteryLabel => isMastered ? '已掌握' : '待复习';

  String get nextReviewLabel {
    if (isMastered) return '已掌握';
    if (nextReviewAt == null) return '建议今天复习';
    final now = DateTime.now();
    final date =
        '${nextReviewAt!.month.toString().padLeft(2, '0')}-${nextReviewAt!.day.toString().padLeft(2, '0')}';
    if (nextReviewAt!.isBefore(now)) return '已到期 · $date';
    return '下次复习 $date';
  }
}

class WrongReviewCalendarDay {
  final String date;
  final int dueCount;
  final int overdueCount;
  final int masteredCount;

  WrongReviewCalendarDay({
    required this.date,
    required this.dueCount,
    required this.overdueCount,
    required this.masteredCount,
  });

  factory WrongReviewCalendarDay.fromJson(Map<String, dynamic> json) {
    return WrongReviewCalendarDay(
      date: json['date'] ?? '',
      dueCount: json['due_count'] ?? 0,
      overdueCount: json['overdue_count'] ?? 0,
      masteredCount: json['mastered_count'] ?? 0,
    );
  }
}

class WrongReviewCalendar {
  final String today;
  final int totalWrong;
  final int dueToday;
  final int overdue;
  final int mastered;
  final List<WrongReviewCalendarDay> upcoming;

  WrongReviewCalendar({
    required this.today,
    required this.totalWrong,
    required this.dueToday,
    required this.overdue,
    required this.mastered,
    required this.upcoming,
  });

  factory WrongReviewCalendar.fromJson(Map<String, dynamic> json) {
    return WrongReviewCalendar(
      today: json['today'] ?? '',
      totalWrong: json['total_wrong'] ?? 0,
      dueToday: json['due_today'] ?? 0,
      overdue: json['overdue'] ?? 0,
      mastered: json['mastered'] ?? 0,
      upcoming: (json['upcoming'] as List? ?? [])
          .map((item) => WrongReviewCalendarDay.fromJson(item))
          .toList(),
    );
  }
}

class WrongReviewFocusItem {
  final String label;
  final int count;
  final String advice;

  WrongReviewFocusItem({
    required this.label,
    required this.count,
    required this.advice,
  });

  factory WrongReviewFocusItem.fromJson(Map<String, dynamic> json) {
    return WrongReviewFocusItem(
      label: json['label'] ?? '',
      count: json['count'] ?? 0,
      advice: json['advice'] ?? '',
    );
  }
}

class WrongReviewPlan {
  final String title;
  final String summary;
  final int dueToday;
  final int overdue;
  final int mastered;
  final int suggestedCount;
  final List<WrongReviewFocusItem> focusTags;
  final List<WrongReviewFocusItem> focusReasons;
  final List<String> actions;

  WrongReviewPlan({
    required this.title,
    required this.summary,
    required this.dueToday,
    required this.overdue,
    required this.mastered,
    required this.suggestedCount,
    required this.focusTags,
    required this.focusReasons,
    required this.actions,
  });

  factory WrongReviewPlan.fromJson(Map<String, dynamic> json) {
    return WrongReviewPlan(
      title: json['title'] ?? '错题复盘',
      summary: json['summary'] ?? '',
      dueToday: json['due_today'] ?? 0,
      overdue: json['overdue'] ?? 0,
      mastered: json['mastered'] ?? 0,
      suggestedCount: json['suggested_count'] ?? 0,
      focusTags: (json['focus_tags'] as List? ?? [])
          .map((item) => WrongReviewFocusItem.fromJson(item))
          .toList(),
      focusReasons: (json['focus_reasons'] as List? ?? [])
          .map((item) => WrongReviewFocusItem.fromJson(item))
          .toList(),
      actions: List<String>.from(json['actions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'summary': summary,
      'due_today': dueToday,
      'overdue': overdue,
      'mastered': mastered,
      'suggested_count': suggestedCount,
      'focus_tags': focusTags
          .map((item) => {
                'label': item.label,
                'count': item.count,
                'advice': item.advice,
              })
          .toList(),
      'focus_reasons': focusReasons
          .map((item) => {
                'label': item.label,
                'count': item.count,
                'advice': item.advice,
              })
          .toList(),
      'actions': actions,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'accuracy_rate': accuracyRate,
      'time_spent': timeSpent,
      'ai_questions': aiQuestions,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'chapter_id': chapterId,
      'chapter_name': chapterName,
      'exam_category': examCategory,
      'practice_count': practiceCount,
      'wrong_count': wrongCount,
      'accuracy_rate': accuracyRate,
      'status': status,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'target_questions': targetQuestions,
      'completed_questions': completedQuestions,
      'accuracy_rate': accuracyRate,
      'time_spent': timeSpent,
      'recommendation_title': recommendationTitle,
      'recommendation_reason': recommendationReason,
      'recommended_mode': recommendedMode,
      'recommended_chapter_id': recommendedChapterId,
      'recommended_tag': recommendedTag,
      'weak_areas': weakAreas.map((item) => item.toJson()).toList(),
    };
  }
}

class StatsOverview {
  final int totalQuestions;
  final int totalCorrect;
  final double overallAccuracy;
  final int totalStudyTime;
  final int currentStreak;
  final Map<String, dynamic> subjectStats;
  final List<AccuracyTrendPoint> accuracyTrend;

  StatsOverview({
    required this.totalQuestions,
    required this.totalCorrect,
    required this.overallAccuracy,
    required this.totalStudyTime,
    required this.currentStreak,
    required this.subjectStats,
    required this.accuracyTrend,
  });

  factory StatsOverview.fromJson(Map<String, dynamic> json) {
    return StatsOverview(
      totalQuestions: json['total_questions'] ?? 0,
      totalCorrect: json['total_correct'] ?? 0,
      overallAccuracy: (json['overall_accuracy'] ?? 0.0).toDouble(),
      totalStudyTime: json['total_study_time'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      subjectStats: json['subject_stats'] ?? {},
      accuracyTrend: (json['accuracy_trend'] as List? ?? [])
          .map((item) => AccuracyTrendPoint.fromJson(item))
          .toList(),
    );
  }
}

class AccuracyTrendPoint {
  final String date;
  final int totalQuestions;
  final int correctCount;
  final double accuracyRate;

  AccuracyTrendPoint({
    required this.date,
    required this.totalQuestions,
    required this.correctCount,
    required this.accuracyRate,
  });

  factory AccuracyTrendPoint.fromJson(Map<String, dynamic> json) {
    return AccuracyTrendPoint(
      date: json['date'] ?? '',
      totalQuestions: json['total_questions'] ?? 0,
      correctCount: json['correct_count'] ?? 0,
      accuracyRate: (json['accuracy_rate'] ?? 0.0).toDouble(),
    );
  }
}
