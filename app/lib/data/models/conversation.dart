class ConversationMessage {
  final int? id;
  final String sessionId;
  final String messageType; // user / assistant
  final String content;
  final int? relatedQuestionId;
  final bool isCollected;
  final DateTime? createdAt;

  ConversationMessage({
    this.id,
    required this.sessionId,
    required this.messageType,
    required this.content,
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
      relatedQuestionId: json['related_question_id'],
      isCollected: json['is_collected'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  bool get isUser => messageType == 'user';
  bool get isAssistant => messageType == 'assistant';
}

class AIAnswer {
  final String answer;
  final String sessionId;
  final List<String> relatedKnowledgePoints;
  final List<String> suggestedQuestions;

  AIAnswer({
    required this.answer,
    required this.sessionId,
    required this.relatedKnowledgePoints,
    required this.suggestedQuestions,
  });

  factory AIAnswer.fromJson(Map<String, dynamic> json) {
    return AIAnswer(
      answer: json['answer'],
      sessionId: json['session_id'],
      relatedKnowledgePoints:
          List<String>.from(json['related_knowledge_points'] ?? []),
      suggestedQuestions:
          List<String>.from(json['suggested_questions'] ?? []),
    );
  }
}
