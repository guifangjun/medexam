import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';

class AIChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<ConversationMessage> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  String _currentSessionId = 'general';
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<ConversationMessage> get messages => _messages;
  List<Map<String, dynamic>> get sessions => _sessions;
  String get currentSessionId => _currentSessionId;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  Future<void> loadSessions() async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getChatSessions();
      _sessions = List<Map<String, dynamic>>.from(res.data);
      _error = null;
    } catch (e) {
      _error = '加载对话列表失败';
    } finally {
      _isLoading = false;
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

  Future<AIAnswer?> sendMessage(String content, {int? relatedQuestionId}) async {
    try {
      _isSending = true;
      _error = null;
      notifyListeners();

      final res = await _api.sendChat(
        content: content,
        relatedQuestionId: relatedQuestionId,
      );

      final answer = AIAnswer.fromJson(res.data);

      // 添加用户消息
      _messages.add(ConversationMessage(
        sessionId: _currentSessionId,
        messageType: 'user',
        content: content,
        relatedQuestionId: relatedQuestionId,
      ));

      // 添加 AI 回复
      _messages.add(ConversationMessage(
        sessionId: _currentSessionId,
        messageType: 'assistant',
        content: answer.answer,
        relatedQuestionId: relatedQuestionId,
      ));

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

  Future<void> collectMessage(int messageId) async {
    try {
      await _api.collectMessage(messageId);
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        // 重新加载以获取最新状态
        await loadHistory(_currentSessionId);
      }
    } catch (e) {
      _error = '收藏失败';
      notifyListeners();
    }
  }

  void startNewSession() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _messages = [];
    notifyListeners();
  }

  void selectSession(String sessionId) {
    loadHistory(sessionId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
