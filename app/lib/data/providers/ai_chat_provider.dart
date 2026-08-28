import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';

class AIChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<ConversationMessage> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  List<ConversationMessage> _collections = [];
  List<AIKnowledgeCard> _knowledgeCards = [];
  String _currentSessionId = _newSessionId();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isLoadingStudyAdvice = false;
  bool _isLoadingLearningPath = false;
  bool _isGeneratingKnowledgeCard = false;
  bool _isLoadingWeaknessReport = false;
  bool _isLoadingErrorPatterns = false;
  bool _isLoadingSprintPlan = false;
  AITextResult? _studyAdvice;
  String? _studyAdviceExamCategory;
  AILearningPath? _learningPath;
  String? _learningPathExamCategory;
  AIWeaknessReport? _weaknessReport;
  String? _weaknessReportExamCategory;
  AIErrorPatternReport? _errorPatternReport;
  String? _errorPatternExamCategory;
  AISprintPlan? _sprintPlan;
  String? _sprintPlanExamCategory;
  String? _error;

  List<ConversationMessage> get messages => _messages;
  List<Map<String, dynamic>> get sessions => _sessions;
  List<ConversationMessage> get collections => _collections;
  List<AIKnowledgeCard> get knowledgeCards => _knowledgeCards;
  String get currentSessionId => _currentSessionId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isLoadingStudyAdvice => _isLoadingStudyAdvice;
  bool get isLoadingLearningPath => _isLoadingLearningPath;
  bool get isGeneratingKnowledgeCard => _isGeneratingKnowledgeCard;
  bool get isLoadingWeaknessReport => _isLoadingWeaknessReport;
  bool get isLoadingErrorPatterns => _isLoadingErrorPatterns;
  bool get isLoadingSprintPlan => _isLoadingSprintPlan;
  int get dueKnowledgeCardCount =>
      _knowledgeCards.where((card) => card.isDue).length;
  AITextResult? get studyAdvice => _studyAdvice;
  String? get studyAdviceExamCategory => _studyAdviceExamCategory;
  AILearningPath? get learningPath => _learningPath;
  String? get learningPathExamCategory => _learningPathExamCategory;
  AIWeaknessReport? get weaknessReport => _weaknessReport;
  String? get weaknessReportExamCategory => _weaknessReportExamCategory;
  AIErrorPatternReport? get errorPatternReport => _errorPatternReport;
  String? get errorPatternExamCategory => _errorPatternExamCategory;
  AISprintPlan? get sprintPlan => _sprintPlan;
  String? get sprintPlanExamCategory => _sprintPlanExamCategory;
  String? get error => _error;

  Future<void> loadSessions({String? examCategory}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getChatSessions(examCategory: examCategory);
      _sessions = List<Map<String, dynamic>>.from(res.data);
      _error = null;
    } catch (e) {
      _error = '加载对话列表失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCollections({String? examCategory}) async {
    try {
      final res = await _api.getChatCollections(examCategory: examCategory);
      _collections = (res.data as List)
          .map((json) => ConversationMessage.fromJson(json))
          .toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = '加载收藏失败';
      notifyListeners();
    }
  }

  Future<void> loadKnowledgeCards({
    String? examCategory,
    bool dueOnly = false,
  }) async {
    try {
      final res = await _api.getAIKnowledgeCards(
        examCategory: examCategory,
        dueOnly: dueOnly,
      );
      _knowledgeCards = (res.data as List)
          .map((json) => AIKnowledgeCard.fromJson(json))
          .toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = '加载 AI 记忆卡失败';
      notifyListeners();
    }
  }

  Future<AIKnowledgeCard?> generateKnowledgeCard({
    required int sourceMessageId,
    required String examCategory,
    String? titleHint,
  }) async {
    if (_isGeneratingKnowledgeCard) return null;
    try {
      _isGeneratingKnowledgeCard = true;
      _error = null;
      notifyListeners();
      final res = await _api.generateAIKnowledgeCard(
        sourceMessageId: sourceMessageId,
        examCategory: examCategory,
        titleHint: titleHint,
      );
      final card = AIKnowledgeCard.fromJson(res.data);
      final index = _knowledgeCards.indexWhere((item) => item.id == card.id);
      if (index == -1) {
        _knowledgeCards.insert(0, card);
      } else {
        _knowledgeCards[index] = card;
      }
      return card;
    } catch (e) {
      _error = 'AI 记忆卡生成失败';
      return null;
    } finally {
      _isGeneratingKnowledgeCard = false;
      notifyListeners();
    }
  }

  Future<bool> reviewKnowledgeCard({
    required int cardId,
    required String rating,
    required String examCategory,
  }) async {
    try {
      final res = await _api.reviewAIKnowledgeCard(cardId, rating);
      final card = AIKnowledgeCard.fromJson(res.data);
      final index = _knowledgeCards.indexWhere((item) => item.id == card.id);
      if (index != -1) _knowledgeCards[index] = card;
      _knowledgeCards.sort((a, b) {
        final aTime = a.nextReviewAt ?? DateTime.now();
        final bTime = b.nextReviewAt ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '记忆卡复习记录失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteKnowledgeCard(int cardId) async {
    try {
      await _api.deleteAIKnowledgeCard(cardId);
      _knowledgeCards.removeWhere((item) => item.id == cardId);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '删除记忆卡失败';
      notifyListeners();
      return false;
    }
  }

  Future<AIWeaknessReport?> buildWeaknessReport({
    required String examCategory,
    int periodDays = 30,
  }) async {
    try {
      _isLoadingWeaknessReport = true;
      _error = null;
      notifyListeners();
      final res = await _api.getAIWeaknessInsights(
        examCategory: examCategory,
        periodDays: periodDays,
      );
      _weaknessReport = AIWeaknessReport.fromJson(res.data);
      _weaknessReportExamCategory = examCategory;
      return _weaknessReport;
    } catch (e) {
      _error = 'AI 薄弱点诊断生成失败';
      return null;
    } finally {
      _isLoadingWeaknessReport = false;
      notifyListeners();
    }
  }

  void clearWeaknessReport({String? exceptExamCategory}) {
    if (exceptExamCategory != null &&
        _weaknessReportExamCategory == exceptExamCategory) {
      return;
    }
    _weaknessReport = null;
    _weaknessReportExamCategory = null;
    notifyListeners();
  }

  Future<AIErrorPatternReport?> buildErrorPatternReport({
    required String examCategory,
    int periodDays = 60,
  }) async {
    try {
      _isLoadingErrorPatterns = true;
      _error = null;
      notifyListeners();
      final res = await _api.getAIErrorPatterns(
        examCategory: examCategory,
        periodDays: periodDays,
      );
      _errorPatternReport = AIErrorPatternReport.fromJson(res.data);
      _errorPatternExamCategory = examCategory;
      return _errorPatternReport;
    } catch (e) {
      _error = 'AI 错因诊断生成失败';
      return null;
    } finally {
      _isLoadingErrorPatterns = false;
      notifyListeners();
    }
  }

  void clearErrorPatternReport({String? exceptExamCategory}) {
    if (exceptExamCategory != null &&
        _errorPatternExamCategory == exceptExamCategory) {
      return;
    }
    if (_errorPatternReport == null && _errorPatternExamCategory == null) {
      return;
    }
    _errorPatternReport = null;
    _errorPatternExamCategory = null;
    notifyListeners();
  }

  Future<AISprintPlan?> buildSprintPlan({
    required String examCategory,
    required DateTime examDate,
    required int dailyMinutes,
    required String intensity,
  }) async {
    try {
      _isLoadingSprintPlan = true;
      _error = null;
      notifyListeners();
      final res = await _api.getAISprintPlan(
        examCategory: examCategory,
        examDate: examDate,
        dailyMinutes: dailyMinutes,
        intensity: intensity,
      );
      _sprintPlan = AISprintPlan.fromJson(res.data);
      _sprintPlanExamCategory = examCategory;
      return _sprintPlan;
    } catch (e) {
      _error = 'AI 冲刺计划生成失败';
      return null;
    } finally {
      _isLoadingSprintPlan = false;
      notifyListeners();
    }
  }

  void clearSprintPlan({String? exceptExamCategory}) {
    if (exceptExamCategory != null &&
        _sprintPlanExamCategory == exceptExamCategory) {
      return;
    }
    if (_sprintPlan == null && _sprintPlanExamCategory == null) return;
    _sprintPlan = null;
    _sprintPlanExamCategory = null;
    notifyListeners();
  }

  Future<void> loadHistory(String sessionId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentSessionId = sessionId;
      final res = await _api.getChatHistory(sessionId);
      _messages = (res.data as List)
          .map((json) => ConversationMessage.fromJson(json))
          .toList();
      _error = null;
    } catch (e) {
      _error = '加载对话历史失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AIAnswer?> sendMessage(
    String content, {
    String? examCategory,
    int? relatedQuestionId,
  }) async {
    try {
      _isSending = true;
      _error = null;
      _messages.add(ConversationMessage(
        sessionId: _currentSessionId,
        messageType: 'user',
        content: content,
        examCategory: examCategory,
        relatedQuestionId: relatedQuestionId,
      ));
      final pendingUserIndex = _messages.length - 1;
      notifyListeners();

      final res = await _api.sendChat(
        content: content,
        sessionId: _currentSessionId,
        examCategory: examCategory,
        relatedQuestionId: relatedQuestionId,
      );

      final answer = AIAnswer.fromJson(res.data);

      // 更新用户消息
      _messages[pendingUserIndex] = ConversationMessage(
        id: answer.userMessageId,
        sessionId: answer.sessionId,
        messageType: 'user',
        content: content,
        examCategory: examCategory,
        relatedQuestionId: relatedQuestionId,
      );

      // 添加 AI 回复
      _messages.add(ConversationMessage(
        id: answer.assistantMessageId,
        sessionId: answer.sessionId,
        messageType: 'assistant',
        content: answer.answer,
        examCategory: examCategory,
        relatedQuestionId: relatedQuestionId,
      ));
      _currentSessionId = answer.sessionId;
      await loadSessions(examCategory: examCategory);

      notifyListeners();
      return answer;
    } catch (e) {
      _error = '发送消息失败，请稍后重试';
      return null;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool?> collectMessage(int messageId, {String? examCategory}) async {
    try {
      final res = await _api.collectMessage(messageId);
      final isCollected = res.data['is_collected'] == true;
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isCollected: isCollected,
        );
      }
      await loadSessions(examCategory: examCategory);
      await loadCollections(examCategory: examCategory);
      notifyListeners();
      _error = null;
      return isCollected;
    } catch (e) {
      _error = '收藏失败';
      notifyListeners();
      return null;
    }
  }

  Future<AITextResult?> explainWrongQuestion({
    int? questionId,
    String? examCategory,
    required String questionContent,
    required Map<String, String> questionOptions,
    String? correctAnswer,
    String? selectedAnswer,
    String? explanation,
    List<String> tags = const [],
  }) async {
    try {
      final res = await _api.getAIWrongExplain({
        if (questionId != null) 'question_id': questionId,
        'exam_category': examCategory,
        'question_content': questionContent,
        'question_options': questionOptions,
        'correct_answer': correctAnswer,
        'selected_answer': selectedAnswer,
        'explanation': explanation,
        'tags': tags,
      });
      return AITextResult.fromJson(res.data);
    } catch (e) {
      _error = 'AI 错题讲解失败';
      notifyListeners();
      return null;
    }
  }

  Future<AITextResult?> buildCourseCoach({
    required String examCategory,
    required int courseId,
    required String courseTitle,
    String? chapterName,
    String? description,
    required int lessonCount,
    required int completedLessons,
    required String stage,
  }) async {
    try {
      _error = null;
      final res = await _api.getAICourseCoach({
        'exam_category': examCategory,
        'course_id': courseId,
        'course_title': courseTitle,
        'chapter_name': chapterName,
        'description': description,
        'lesson_count': lessonCount,
        'completed_lessons': completedLessons,
        'stage': stage,
      });
      return AITextResult.fromJson(res.data);
    } catch (e) {
      _error = 'AI 课程伴学建议生成失败';
      notifyListeners();
      return null;
    }
  }

  Future<AITextResult?> buildPracticeReview({
    required String examCategory,
    required String practiceTitle,
    required int totalQuestions,
    required int answeredCount,
    required int correctCount,
    required int wrongCount,
    required int timeSpent,
    required Map<String, int> wrongTags,
  }) async {
    try {
      _error = null;
      final res = await _api.getAIPracticeReview({
        'exam_category': examCategory,
        'practice_title': practiceTitle,
        'total_questions': totalQuestions,
        'answered_count': answeredCount,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'time_spent': timeSpent,
        'wrong_tags': wrongTags,
      });
      return AITextResult.fromJson(res.data);
    } catch (e) {
      _error = 'AI 练习小结生成失败';
      notifyListeners();
      return null;
    }
  }

  Future<AIReasoningEvaluation?> evaluateReasoning({
    int? questionId,
    required String examCategory,
    required String questionContent,
    String? correctAnswer,
    String? selectedAnswer,
    String? referenceExplanation,
    required String learnerReasoning,
    required bool isCorrect,
    List<String> tags = const [],
  }) async {
    try {
      _error = null;
      final res = await _api.evaluateAIReasoning({
        if (questionId != null) 'question_id': questionId,
        'exam_category': examCategory,
        'question_content': questionContent,
        'correct_answer': correctAnswer,
        'selected_answer': selectedAnswer,
        'reference_explanation': referenceExplanation,
        'learner_reasoning': learnerReasoning,
        'is_correct': isCorrect,
        'tags': tags,
      });
      return AIReasoningEvaluation.fromJson(res.data);
    } catch (e) {
      _error = 'AI 复述评测失败';
      notifyListeners();
      return null;
    }
  }

  Future<AICaseSimulation?> generateCaseSimulation({
    required String examCategory,
    String? topic,
    int difficulty = 2,
    int? chapterId,
  }) async {
    try {
      _error = null;
      final res = await _api.generateAICaseSimulation(
        examCategory: examCategory,
        topic: topic,
        difficulty: difficulty,
        chapterId: chapterId,
      );
      return AICaseSimulation.fromJson(res.data);
    } catch (e) {
      _error = 'AI 病例生成失败，当前科目可能缺少足够题目';
      notifyListeners();
      return null;
    }
  }

  Future<AICaseReview?> reviewCaseSimulation({
    required AICaseSimulation simulation,
    required Map<int, String> answers,
  }) async {
    try {
      _error = null;
      final answerItems = simulation.stages
          .map(
            (stage) => {
              'stage_index': stage.index,
              'stage_title': stage.title,
              'selected_answer': answers[stage.index] ?? '',
              'best_answer': stage.bestAnswer,
              'knowledge_point': stage.knowledgePoint,
            },
          )
          .toList();
      final res = await _api.reviewAICaseSimulation({
        'case_id': simulation.caseId,
        'exam_category': simulation.examCategory,
        'case_title': simulation.title,
        'topic': simulation.topic,
        'answers': answerItems,
      });
      return AICaseReview.fromJson(res.data);
    } catch (e) {
      _error = 'AI 病例复盘生成失败';
      notifyListeners();
      return null;
    }
  }

  Future<AITextResult?> buildStudyAdvice({
    required String examCategory,
    required Map<String, dynamic> todayStats,
    List<Map<String, dynamic>> weakAreas = const [],
    Map<String, dynamic> wrongSummary = const {},
  }) async {
    try {
      _isLoadingStudyAdvice = true;
      _error = null;
      notifyListeners();

      final res = await _api.getAIStudyAdvice({
        'exam_category': examCategory,
        'today_stats': todayStats,
        'weak_areas': weakAreas,
        'wrong_summary': wrongSummary,
      });
      _studyAdvice = AITextResult.fromJson(res.data);
      _studyAdviceExamCategory = examCategory;
      return _studyAdvice;
    } catch (e) {
      _error = 'AI 学习建议生成失败';
      return null;
    } finally {
      _isLoadingStudyAdvice = false;
      notifyListeners();
    }
  }

  void clearStudyAdvice({String? exceptExamCategory}) {
    if (exceptExamCategory != null &&
        _studyAdviceExamCategory == exceptExamCategory) {
      return;
    }
    if (_studyAdvice == null && _studyAdviceExamCategory == null) return;
    _studyAdvice = null;
    _studyAdviceExamCategory = null;
    notifyListeners();
  }

  Future<AITextResult?> buildExamReport({
    int? attemptId,
    required String examCategory,
    required int totalQuestions,
    required int correctCount,
    required int wrongCount,
    required int unansweredCount,
    required double accuracyRate,
    required int timeSpent,
    Map<String, int> weakTags = const {},
  }) async {
    try {
      final res = await _api.getAIExamReport({
        if (attemptId != null) 'attempt_id': attemptId,
        'exam_category': examCategory,
        'total_questions': totalQuestions,
        'correct_count': correctCount,
        'wrong_count': wrongCount,
        'unanswered_count': unansweredCount,
        'accuracy_rate': accuracyRate,
        'time_spent': timeSpent,
        'weak_tags': weakTags,
      });
      return AITextResult.fromJson(res.data);
    } catch (e) {
      _error = 'AI 模考报告失败';
      notifyListeners();
      return null;
    }
  }

  Future<AILearningPath?> buildLearningPath({
    required String examCategory,
    required Map<String, dynamic> todayStats,
    Map<String, dynamic> prescription = const {},
    Map<String, dynamic> wrongReview = const {},
  }) async {
    try {
      _isLoadingLearningPath = true;
      _error = null;
      notifyListeners();

      final res = await _api.getAILearningPath({
        'exam_category': examCategory,
        'today_stats': todayStats,
        'prescription': prescription,
        'wrong_review': wrongReview,
      });
      _learningPath = AILearningPath.fromJson(res.data);
      _learningPathExamCategory = examCategory;
      return _learningPath;
    } catch (e) {
      _error = 'AI 学习路径生成失败';
      return null;
    } finally {
      _isLoadingLearningPath = false;
      notifyListeners();
    }
  }

  void clearLearningPath({String? exceptExamCategory}) {
    if (exceptExamCategory != null &&
        _learningPathExamCategory == exceptExamCategory) {
      return;
    }
    if (_learningPath == null && _learningPathExamCategory == null) return;
    _learningPath = null;
    _learningPathExamCategory = null;
    notifyListeners();
  }

  void startNewSession() {
    _currentSessionId = _newSessionId();
    _messages = [];
    notifyListeners();
  }

  void ensureFreshVisibleSession() {
    if (_messages.isNotEmpty) return;
    if (!_currentSessionId.startsWith('new-')) {
      _currentSessionId = _newSessionId();
      notifyListeners();
    }
  }

  void selectSession(String sessionId) {
    loadHistory(sessionId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearUserSession() {
    _messages = [];
    _sessions = [];
    _collections = [];
    _knowledgeCards = [];
    _currentSessionId = _newSessionId();
    _isLoading = false;
    _isSending = false;
    _isLoadingStudyAdvice = false;
    _isLoadingLearningPath = false;
    _isGeneratingKnowledgeCard = false;
    _isLoadingWeaknessReport = false;
    _isLoadingErrorPatterns = false;
    _isLoadingSprintPlan = false;
    _studyAdvice = null;
    _studyAdviceExamCategory = null;
    _learningPath = null;
    _learningPathExamCategory = null;
    _weaknessReport = null;
    _weaknessReportExamCategory = null;
    _errorPatternReport = null;
    _errorPatternExamCategory = null;
    _sprintPlan = null;
    _sprintPlanExamCategory = null;
    _error = null;
    notifyListeners();
  }

  static String _newSessionId() =>
      'new-${DateTime.now().microsecondsSinceEpoch}';
}
