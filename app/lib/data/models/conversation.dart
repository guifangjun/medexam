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
