import 'question.dart';

class ConversationMessage {
  final int? id;
  final String sessionId;
  final String messageType; // user / assistant
  final String content;
  final String? examCategory;
  final int? relatedQuestionId;
  final bool isCollected;
  final DateTime? createdAt;

  ConversationMessage({
    this.id,
    required this.sessionId,
    required this.messageType,
    required this.content,
    this.examCategory,
    this.relatedQuestionId,
    this.isCollected = false,
    this.createdAt,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'],
      sessionId: json['session_id'],
      messageType: json['message_type'],
      content: json['content'],
      examCategory: json['exam_category'],
      relatedQuestionId: json['related_question_id'],
      isCollected: json['is_collected'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  bool get isUser => messageType == 'user';
  bool get isAssistant => messageType == 'assistant';

  ConversationMessage copyWith({
    int? id,
    String? sessionId,
    String? messageType,
    String? content,
    String? examCategory,
    int? relatedQuestionId,
    bool? isCollected,
    DateTime? createdAt,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      examCategory: examCategory ?? this.examCategory,
      relatedQuestionId: relatedQuestionId ?? this.relatedQuestionId,
      isCollected: isCollected ?? this.isCollected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AIAnswer {
  final String answer;
  final String sessionId;
  final int? userMessageId;
  final int? assistantMessageId;
  final List<String> relatedKnowledgePoints;
  final List<String> suggestedQuestions;

  AIAnswer({
    required this.answer,
    required this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
    required this.relatedKnowledgePoints,
    required this.suggestedQuestions,
  });

  factory AIAnswer.fromJson(Map<String, dynamic> json) {
    return AIAnswer(
      answer: json['answer'],
      sessionId: json['session_id'],
      userMessageId: json['user_message_id'],
      assistantMessageId: json['assistant_message_id'],
      relatedKnowledgePoints:
          List<String>.from(json['related_knowledge_points'] ?? []),
      suggestedQuestions: List<String>.from(json['suggested_questions'] ?? []),
    );
  }
}

class AITextResult {
  final String title;
  final String content;
  final List<String> actions;
  final bool isDemo;
  final String? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;

  AITextResult({
    required this.title,
    required this.content,
    required this.actions,
    required this.isDemo,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
  });

  factory AITextResult.fromJson(Map<String, dynamic> json) {
    return AITextResult(
      title: json['title'] ?? 'AI 建议',
      content: _cleanReadableText(json['content'] ?? ''),
      actions: List<String>.from(json['actions'] ?? []),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      userMessageId: json['user_message_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }
}

class AIReasoningEvaluation {
  final String title;
  final int score;
  final String verdict;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> coachingQuestions;
  final String modelReasoning;
  final String nextAction;
  final bool isDemo;
  final String? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;

  AIReasoningEvaluation({
    required this.title,
    required this.score,
    required this.verdict,
    required this.strengths,
    required this.gaps,
    required this.coachingQuestions,
    required this.modelReasoning,
    required this.nextAction,
    required this.isDemo,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
  });

  factory AIReasoningEvaluation.fromJson(Map<String, dynamic> json) {
    return AIReasoningEvaluation(
      title: json['title'] ?? 'AI 费曼复述评测',
      score: json['score'] ?? 0,
      verdict: _cleanReadableText(json['verdict'] ?? ''),
      strengths: List<String>.from(json['strengths'] ?? []),
      gaps: List<String>.from(json['gaps'] ?? []),
      coachingQuestions: List<String>.from(json['coaching_questions'] ?? []),
      modelReasoning: _cleanReadableText(json['model_reasoning'] ?? ''),
      nextAction: _cleanReadableText(json['next_action'] ?? ''),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      userMessageId: json['user_message_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }

  String get masteryLabel {
    if (score >= 85) return '理解扎实';
    if (score >= 70) return '基本掌握';
    if (score >= 55) return '仍有缺口';
    return '需要重学';
  }
}

class AICaseSimulationStage {
  final int index;
  final String title;
  final String scenario;
  final String prompt;
  final Map<String, String> options;
  final String bestAnswer;
  final String explanation;
  final String hint;
  final String knowledgePoint;
  final int? sourceQuestionId;

  AICaseSimulationStage({
    required this.index,
    required this.title,
    required this.scenario,
    required this.prompt,
    required this.options,
    required this.bestAnswer,
    required this.explanation,
    required this.hint,
    required this.knowledgePoint,
    this.sourceQuestionId,
  });

  factory AICaseSimulationStage.fromJson(Map<String, dynamic> json) {
    return AICaseSimulationStage(
      index: json['index'] ?? 0,
      title: json['title'] ?? '',
      scenario: _cleanReadableText(json['scenario'] ?? ''),
      prompt: _cleanReadableText(json['prompt'] ?? ''),
      options: Map<String, String>.from(json['options'] ?? {}),
      bestAnswer: json['best_answer'] ?? '',
      explanation: _cleanReadableText(json['explanation'] ?? ''),
      hint: _cleanReadableText(json['hint'] ?? ''),
      knowledgePoint: json['knowledge_point'] ?? '',
      sourceQuestionId: json['source_question_id'],
    );
  }
}

class AICaseSimulation {
  final String caseId;
  final String title;
  final String examCategory;
  final String topic;
  final int difficulty;
  final String patientProfile;
  final String chiefComplaint;
  final List<String> learningObjectives;
  final List<AICaseSimulationStage> stages;
  final bool isDemo;

  AICaseSimulation({
    required this.caseId,
    required this.title,
    required this.examCategory,
    required this.topic,
    required this.difficulty,
    required this.patientProfile,
    required this.chiefComplaint,
    required this.learningObjectives,
    required this.stages,
    required this.isDemo,
  });

  factory AICaseSimulation.fromJson(Map<String, dynamic> json) {
    return AICaseSimulation(
      caseId: json['case_id'] ?? '',
      title: json['title'] ?? 'AI 临床病例推演',
      examCategory: json['exam_category'] ?? '',
      topic: json['topic'] ?? '',
      difficulty: json['difficulty'] ?? 2,
      patientProfile: _cleanReadableText(json['patient_profile'] ?? ''),
      chiefComplaint: _cleanReadableText(json['chief_complaint'] ?? ''),
      learningObjectives: List<String>.from(json['learning_objectives'] ?? []),
      stages: (json['stages'] as List? ?? [])
          .map((item) => AICaseSimulationStage.fromJson(item))
          .toList(),
      isDemo: json['is_demo'] ?? false,
    );
  }
}

class AICaseReview {
  final String title;
  final int score;
  final int correctCount;
  final int totalStages;
  final String summary;
  final List<String> wrongPoints;
  final List<String> actions;
  final bool isDemo;
  final String? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;

  AICaseReview({
    required this.title,
    required this.score,
    required this.correctCount,
    required this.totalStages,
    required this.summary,
    required this.wrongPoints,
    required this.actions,
    required this.isDemo,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
  });

  factory AICaseReview.fromJson(Map<String, dynamic> json) {
    return AICaseReview(
      title: json['title'] ?? 'AI 病例推演复盘',
      score: json['score'] ?? 0,
      correctCount: json['correct_count'] ?? 0,
      totalStages: json['total_stages'] ?? 0,
      summary: _cleanReadableText(json['summary'] ?? ''),
      wrongPoints: List<String>.from(json['wrong_points'] ?? []),
      actions: List<String>.from(json['actions'] ?? []),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      userMessageId: json['user_message_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }
}

class AIAdaptivePracticePlan {
  final String title;
  final String strategy;
  final int? focusChapterId;
  final String focusChapterName;
  final int targetDifficulty;
  final int targetAccuracy;
  final int estimatedMinutes;
  final int questionCount;
  final Map<String, int> selectionBreakdown;
  final List<String> reasons;
  final String nextAdjustmentHint;
  final List<Question> questions;
  final bool isDemo;
  final String? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;

  AIAdaptivePracticePlan({
    required this.title,
    required this.strategy,
    this.focusChapterId,
    required this.focusChapterName,
    required this.targetDifficulty,
    required this.targetAccuracy,
    required this.estimatedMinutes,
    required this.questionCount,
    required this.selectionBreakdown,
    required this.reasons,
    required this.nextAdjustmentHint,
    required this.questions,
    required this.isDemo,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
  });

  factory AIAdaptivePracticePlan.fromJson(Map<String, dynamic> json) {
    return AIAdaptivePracticePlan(
      title: json['title'] ?? 'AI 自适应练习',
      strategy: _cleanReadableText(json['strategy'] ?? ''),
      focusChapterId: json['focus_chapter_id'],
      focusChapterName: json['focus_chapter_name'] ?? '全科综合',
      targetDifficulty: json['target_difficulty'] ?? 2,
      targetAccuracy: json['target_accuracy'] ?? 75,
      estimatedMinutes: json['estimated_minutes'] ?? 15,
      questionCount: json['question_count'] ?? 0,
      selectionBreakdown: Map<String, int>.from(
        json['selection_breakdown'] ?? {},
      ),
      reasons: List<String>.from(json['reasons'] ?? []),
      nextAdjustmentHint:
          _cleanReadableText(json['next_adjustment_hint'] ?? ''),
      questions: (json['questions'] as List? ?? [])
          .map((item) => Question.fromJson(item))
          .toList(),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      userMessageId: json['user_message_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }

  int get unseenCount => selectionBreakdown['unseen'] ?? 0;
  int get weakReviewCount => selectionBreakdown['weak_review'] ?? 0;
  int get spacedReviewCount => selectionBreakdown['spaced_review'] ?? 0;
}

class AIKnowledgeCard {
  final int id;
  final String examCategory;
  final int? sourceMessageId;
  final int? relatedQuestionId;
  final String title;
  final String front;
  final String back;
  final String? mnemonic;
  final List<String> tags;
  final int masteryLevel;
  final int reviewCount;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final DateTime createdAt;

  AIKnowledgeCard({
    required this.id,
    required this.examCategory,
    this.sourceMessageId,
    this.relatedQuestionId,
    required this.title,
    required this.front,
    required this.back,
    this.mnemonic,
    required this.tags,
    required this.masteryLevel,
    required this.reviewCount,
    this.lastReviewedAt,
    this.nextReviewAt,
    required this.createdAt,
  });

  factory AIKnowledgeCard.fromJson(Map<String, dynamic> json) {
    return AIKnowledgeCard(
      id: json['id'],
      examCategory: json['exam_category'] ?? '',
      sourceMessageId: json['source_message_id'],
      relatedQuestionId: json['related_question_id'],
      title: json['title'] ?? 'AI 记忆卡',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      mnemonic: json['mnemonic'],
      tags: List<String>.from(json['tags'] ?? []),
      masteryLevel: json['mastery_level'] ?? 0,
      reviewCount: json['review_count'] ?? 0,
      lastReviewedAt: json['last_reviewed_at'] == null
          ? null
          : DateTime.parse(json['last_reviewed_at']),
      nextReviewAt: json['next_review_at'] == null
          ? null
          : DateTime.parse(json['next_review_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isDue =>
      nextReviewAt == null || !nextReviewAt!.isAfter(DateTime.now());

  String get masteryLabel {
    if (masteryLevel >= 4) return '已掌握';
    if (masteryLevel >= 2) return '巩固中';
    return '待复习';
  }

  String get nextReviewLabel {
    final next = nextReviewAt;
    if (next == null || isDue) return '现在复习';
    final today = DateTime.now();
    final startToday = DateTime(today.year, today.month, today.day);
    final target = DateTime(next.year, next.month, next.day);
    final days = target.difference(startToday).inDays;
    if (days <= 1) return '明天复习';
    return '$days 天后复习';
  }
}

class AIWeaknessInsight {
  final int chapterId;
  final String chapterName;
  final int recentQuestions;
  final int previousQuestions;
  final double recentAccuracy;
  final double? previousAccuracy;
  final double? trendDelta;
  final String trend;
  final int wrongCount;
  final String status;
  final String recommendation;

  AIWeaknessInsight({
    required this.chapterId,
    required this.chapterName,
    required this.recentQuestions,
    required this.previousQuestions,
    required this.recentAccuracy,
    this.previousAccuracy,
    this.trendDelta,
    required this.trend,
    required this.wrongCount,
    required this.status,
    required this.recommendation,
  });

  factory AIWeaknessInsight.fromJson(Map<String, dynamic> json) {
    return AIWeaknessInsight(
      chapterId: json['chapter_id'],
      chapterName: json['chapter_name'] ?? '',
      recentQuestions: json['recent_questions'] ?? 0,
      previousQuestions: json['previous_questions'] ?? 0,
      recentAccuracy: (json['recent_accuracy'] ?? 0.0).toDouble(),
      previousAccuracy: json['previous_accuracy'] == null
          ? null
          : (json['previous_accuracy'] as num).toDouble(),
      trendDelta: json['trend_delta'] == null
          ? null
          : (json['trend_delta'] as num).toDouble(),
      trend: json['trend'] ?? '数据积累中',
      wrongCount: json['wrong_count'] ?? 0,
      status: json['status'] ?? '待诊断',
      recommendation: json['recommendation'] ?? '',
    );
  }
}

class AIWeaknessReport {
  final String title;
  final String summary;
  final int periodDays;
  final int totalRecords;
  final List<AIWeaknessInsight> items;
  final List<String> actions;
  final bool isDemo;
  final String? sessionId;
  final int? assistantMessageId;

  AIWeaknessReport({
    required this.title,
    required this.summary,
    required this.periodDays,
    required this.totalRecords,
    required this.items,
    required this.actions,
    required this.isDemo,
    this.sessionId,
    this.assistantMessageId,
  });

  factory AIWeaknessReport.fromJson(Map<String, dynamic> json) {
    return AIWeaknessReport(
      title: json['title'] ?? 'AI 长期薄弱点追踪',
      summary: _cleanReadableText(json['summary'] ?? ''),
      periodDays: json['period_days'] ?? 30,
      totalRecords: json['total_records'] ?? 0,
      items: (json['items'] as List? ?? [])
          .map((item) => AIWeaknessInsight.fromJson(item))
          .toList(),
      actions: List<String>.from(json['actions'] ?? []),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }
}

class AIErrorPattern {
  final String key;
  final String name;
  final int count;
  final double percentage;
  final String severity;
  final String diagnosis;
  final List<String> evidence;
  final String correction;
  final int? chapterId;
  final String? chapterName;
  final String? tag;
  final String mode;
  final List<int> questionIds;

  AIErrorPattern({
    required this.key,
    required this.name,
    required this.count,
    required this.percentage,
    required this.severity,
    required this.diagnosis,
    required this.evidence,
    required this.correction,
    this.chapterId,
    this.chapterName,
    this.tag,
    required this.mode,
    required this.questionIds,
  });

  factory AIErrorPattern.fromJson(Map<String, dynamic> json) {
    return AIErrorPattern(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] as num? ?? 0).toDouble(),
      severity: json['severity'] ?? '低',
      diagnosis: json['diagnosis'] ?? '',
      evidence: List<String>.from(json['evidence'] ?? []),
      correction: json['correction'] ?? '',
      chapterId: json['chapter_id'],
      chapterName: json['chapter_name'],
      tag: json['tag'],
      mode: json['mode'] ?? 'wrong',
      questionIds: List<int>.from(json['question_ids'] ?? []),
    );
  }
}

class AIErrorPatternReport {
  final String title;
  final String summary;
  final String examCategory;
  final int periodDays;
  final int totalWrong;
  final int analyzedRecords;
  final String? topPattern;
  final List<AIErrorPattern> patterns;
  final List<String> trainingSequence;
  final List<String> actions;
  final bool isDemo;
  final String? sessionId;
  final int? assistantMessageId;

  AIErrorPatternReport({
    required this.title,
    required this.summary,
    required this.examCategory,
    required this.periodDays,
    required this.totalWrong,
    required this.analyzedRecords,
    this.topPattern,
    required this.patterns,
    required this.trainingSequence,
    required this.actions,
    required this.isDemo,
    this.sessionId,
    this.assistantMessageId,
  });

  factory AIErrorPatternReport.fromJson(Map<String, dynamic> json) {
    return AIErrorPatternReport(
      title: json['title'] ?? 'AI 错因雷达',
      summary: _cleanReadableText(json['summary'] ?? ''),
      examCategory: json['exam_category'] ?? '',
      periodDays: json['period_days'] ?? 60,
      totalWrong: json['total_wrong'] ?? 0,
      analyzedRecords: json['analyzed_records'] ?? 0,
      topPattern: json['top_pattern'],
      patterns: (json['patterns'] as List? ?? [])
          .map((item) => AIErrorPattern.fromJson(item))
          .toList(),
      trainingSequence: List<String>.from(json['training_sequence'] ?? []),
      actions: List<String>.from(json['actions'] ?? []),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }
}

class AISprintPriorityChapter {
  final int chapterId;
  final String chapterName;
  final double? accuracyRate;
  final int practicedQuestions;
  final String reason;

  AISprintPriorityChapter({
    required this.chapterId,
    required this.chapterName,
    this.accuracyRate,
    required this.practicedQuestions,
    required this.reason,
  });

  factory AISprintPriorityChapter.fromJson(Map<String, dynamic> json) {
    return AISprintPriorityChapter(
      chapterId: json['chapter_id'] ?? 0,
      chapterName: json['chapter_name'] ?? '',
      accuracyRate: (json['accuracy_rate'] as num?)?.toDouble(),
      practicedQuestions: json['practiced_questions'] ?? 0,
      reason: json['reason'] ?? '',
    );
  }
}

class AISprintPhase {
  final String name;
  final int startDay;
  final int endDay;
  final int days;
  final String focus;
  final List<String> dailyActions;
  final String milestone;

  AISprintPhase({
    required this.name,
    required this.startDay,
    required this.endDay,
    required this.days,
    required this.focus,
    required this.dailyActions,
    required this.milestone,
  });

  factory AISprintPhase.fromJson(Map<String, dynamic> json) {
    return AISprintPhase(
      name: json['name'] ?? '',
      startDay: json['start_day'] ?? 1,
      endDay: json['end_day'] ?? 1,
      days: json['days'] ?? 1,
      focus: json['focus'] ?? '',
      dailyActions: List<String>.from(json['daily_actions'] ?? []),
      milestone: json['milestone'] ?? '',
    );
  }
}

class AISprintPlan {
  final String title;
  final String summary;
  final String examCategory;
  final DateTime examDate;
  final int daysRemaining;
  final int dailyMinutes;
  final int dailyQuestions;
  final int weeklyMockExams;
  final String intensity;
  final List<AISprintPriorityChapter> priorityChapters;
  final List<AISprintPhase> phases;
  final List<String> dailySchedule;
  final List<String> todayActions;
  final List<String> riskAlerts;
  final bool isDemo;
  final String? sessionId;
  final int? assistantMessageId;

  AISprintPlan({
    required this.title,
    required this.summary,
    required this.examCategory,
    required this.examDate,
    required this.daysRemaining,
    required this.dailyMinutes,
    required this.dailyQuestions,
    required this.weeklyMockExams,
    required this.intensity,
    required this.priorityChapters,
    required this.phases,
    required this.dailySchedule,
    required this.todayActions,
    required this.riskAlerts,
    required this.isDemo,
    this.sessionId,
    this.assistantMessageId,
  });

  String get intensityLabel => switch (intensity) {
        'sprint' => '冲刺',
        'accelerated' => '加速',
        _ => '稳步',
      };

  factory AISprintPlan.fromJson(Map<String, dynamic> json) {
    return AISprintPlan(
      title: json['title'] ?? 'AI 冲刺计划',
      summary: _cleanReadableText(json['summary'] ?? ''),
      examCategory: json['exam_category'] ?? '',
      examDate: DateTime.parse(json['exam_date']),
      daysRemaining: json['days_remaining'] ?? 1,
      dailyMinutes: json['daily_minutes'] ?? 60,
      dailyQuestions: json['daily_questions'] ?? 20,
      weeklyMockExams: json['weekly_mock_exams'] ?? 1,
      intensity: json['intensity'] ?? 'steady',
      priorityChapters: (json['priority_chapters'] as List? ?? [])
          .map((item) => AISprintPriorityChapter.fromJson(item))
          .toList(),
      phases: (json['phases'] as List? ?? [])
          .map((item) => AISprintPhase.fromJson(item))
          .toList(),
      dailySchedule: List<String>.from(json['daily_schedule'] ?? []),
      todayActions: List<String>.from(json['today_actions'] ?? []),
      riskAlerts: List<String>.from(json['risk_alerts'] ?? []),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }
}

class AILearningPathStep {
  final String day;
  final String title;
  final String focus;
  final String action;
  final String mode;
  final int? chapterId;
  final String? tag;

  AILearningPathStep({
    required this.day,
    required this.title,
    required this.focus,
    required this.action,
    required this.mode,
    this.chapterId,
    this.tag,
  });

  factory AILearningPathStep.fromJson(Map<String, dynamic> json) {
    return AILearningPathStep(
      day: json['day'] ?? '',
      title: json['title'] ?? '',
      focus: json['focus'] ?? '',
      action: json['action'] ?? '',
      mode: json['mode'] ?? 'random',
      chapterId: json['chapter_id'],
      tag: json['tag'],
    );
  }
}

class AILearningPath {
  final String title;
  final String summary;
  final String todayChallenge;
  final String rewardTitle;
  final List<String> microTasks;
  final int estimatedMinutes;
  final List<AILearningPathStep> steps;
  final List<String> actions;
  final bool isDemo;
  final String? sessionId;
  final int? userMessageId;
  final int? assistantMessageId;

  AILearningPath({
    required this.title,
    required this.summary,
    required this.todayChallenge,
    required this.rewardTitle,
    required this.microTasks,
    required this.estimatedMinutes,
    required this.steps,
    required this.actions,
    required this.isDemo,
    this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
  });

  factory AILearningPath.fromJson(Map<String, dynamic> json) {
    return AILearningPath(
      title: json['title'] ?? 'AI 学习路径',
      summary: _cleanReadableText(json['summary'] ?? ''),
      todayChallenge: json['today_challenge'] ?? '',
      rewardTitle: json['reward_title'] ?? '今日坚持勋章',
      microTasks: List<String>.from(json['micro_tasks'] ?? []),
      estimatedMinutes: json['estimated_minutes'] ?? 20,
      steps: (json['steps'] as List? ?? [])
          .map((item) => AILearningPathStep.fromJson(item))
          .toList(),
      actions: List<String>.from(json['actions'] ?? []),
      isDemo: json['is_demo'] ?? false,
      sessionId: json['session_id'],
      userMessageId: json['user_message_id'],
      assistantMessageId: json['assistant_message_id'],
    );
  }
}

String _cleanReadableText(String text) {
  return text
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
