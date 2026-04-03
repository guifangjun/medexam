import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/chapter.dart';
import '../services/api_service.dart';

class QuestionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Chapter> _chapters = [];
  List<Question> _currentQuestions = [];
  int _currentIndex = 0;
  Question? _currentQuestion;
  SubmitResult? _lastResult;
  bool _isLoading = false;
  String? _error;

  // 做题计时
  DateTime? _questionStartTime;

  List<Chapter> get chapters => _chapters;
  List<Question> get currentQuestions => _currentQuestions;
  int get currentIndex => _currentIndex;
  Question? get currentQuestion => _currentQuestion;
  SubmitResult? get lastResult => _lastResult;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasQuestions => _currentQuestions.isNotEmpty;
  bool get isLastQuestion => _currentIndex >= _currentQuestions.length - 1;

  double get progress {
    if (_currentQuestions.isEmpty) return 0;
    return (_currentIndex + 1) / _currentQuestions.length;
  }

  Future<void> loadChapters() async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getChapters();
      _chapters = (res.data as List)
          .map((json) => Chapter.fromJson(json))
          .toList();
      _error = null;
    } catch (e) {
      _error = '加载章节失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPracticeQuestions({
    int? chapterId,
    int? difficulty,
    int limit = 20,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _api.getPracticeQuestions(
        chapterId: chapterId,
        difficulty: difficulty,
        limit: limit,
      );
      _currentQuestions = (res.data as List)
          .map((json) => Question.fromJson(json))
          .toList();
      _currentIndex = 0;
      _lastResult = null;
      _questionStartTime = DateTime.now();
      if (_currentQuestions.isNotEmpty) {
        _currentQuestion = _currentQuestions[0];
      }
    } catch (e) {
      _error = '加载题目失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadExamQuestions({int count = 50}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _api.getExamQuestions(count: count);
      _currentQuestions = (res.data as List)
          .map((json) => Question.fromJson(json))
          .toList();
      _currentIndex = 0;
      _lastResult = null;
      _questionStartTime = DateTime.now();
      if (_currentQuestions.isNotEmpty) {
        _currentQuestion = _currentQuestions[0];
      }
    } catch (e) {
      _error = '加载考试题目失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SubmitResult?> submitAnswer(String selectedAnswer) async {
    if (_currentQuestion == null) return null;

    final timeSpent = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inSeconds
        : 0;

    try {
      final res = await _api.submitQuestion({
        'question_id': _currentQuestion!.id,
        'selected_answer': selectedAnswer,
        'time_spent': timeSpent,
      });
      _lastResult = SubmitResult.fromJson(res.data);
      notifyListeners();
      return _lastResult;
    } catch (e) {
      _error = '提交答案失败';
      notifyListeners();
      return null;
    }
  }

  void nextQuestion() {
    if (_currentIndex < _currentQuestions.length - 1) {
      _currentIndex++;
      _currentQuestion = _currentQuestions[_currentIndex];
      _lastResult = null;
      _questionStartTime = DateTime.now();
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _currentQuestion = _currentQuestions[_currentIndex];
      _lastResult = null;
      notifyListeners();
    }
  }

  void reset() {
    _currentQuestions = [];
    _currentIndex = 0;
    _currentQuestion = null;
    _lastResult = null;
    _questionStartTime = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
