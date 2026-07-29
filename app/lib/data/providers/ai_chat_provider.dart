import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';

class AIChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<ConversationMessage> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  List<ConversationMessage> _collections = [];
  String _currentSessionId = _newSessionId();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isLoadingStudyAdvice = false;
  bool _isLoadingLearningPath = false;
  AITextResult? _studyAdvice;
  String? _studyAdviceExamCategory;
  AILearningPath? _learningPath;
  String? _learningPathExamCategory;
  String? _error;

  List<ConversationMessage> get messages => _messages;
  List<Map<String, dynamic>> get sessions => _sessions;
  List<ConversationMessage> get collections => _collections;
  String get currentSessionId => _currentSessionId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isLoadingStudyAdvice => _isLoadingStudyAdvice;
  bool get isLoadingLearningPath => _isLoadingLearningPath;
  AITextResult? get studyAdvice => _studyAdvice;
  String? get studyAdviceExamCategory => _studyAdviceExamCategory;
  AILearningPath? get learningPath => _learningPath;
  String? get learningPathExamCategory => _learningPathExamCategory;
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
    _currentSessionId = _newSessionId();
    _isLoading = false;
    _isSending = false;
    _isLoadingStudyAdvice = false;
    _isLoadingLearningPath = false;
    _studyAdvice = null;
    _studyAdviceExamCategory = null;
    _learningPath = null;
    _learningPathExamCategory = null;
    _error = null;
    notifyListeners();
  }

  static String _newSessionId() =>
      'new-${DateTime.now().microsecondsSinceEpoch}';
}
