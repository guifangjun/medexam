import 'package:flutter/material.dart';
import '../models/study.dart';
import '../services/api_service.dart';

class StudyProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<StudyPlan> _plans = [];
  DailyTask? _todayTask;
  List<WrongQuestion> _wrongQuestions = [];
  StudyStats? _todayStats;
  StatsOverview? _overview;
  bool _isLoading = false;
  String? _error;

  List<StudyPlan> get plans => _plans;
  DailyTask? get todayTask => _todayTask;
  List<WrongQuestion> get wrongQuestions => _wrongQuestions;
  StudyStats? get todayStats => _todayStats;
  StatsOverview? get overview => _overview;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTodayTask() async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getTodayTask();
      _todayTask = DailyTask.fromJson(res.data);
      _error = null;
    } catch (e) {
      _error = '加载今日任务失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudyPlans() async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getStudyPlans();
      _plans = (res.data as List)
          .map((json) => StudyPlan.fromJson(json))
          .toList();
      _error = null;
    } catch (e) {
      _error = '加载学习计划失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStudyPlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    List<int> targetChapters = const [],
    int dailyQuestions = 20,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _api.createStudyPlan({
        'title': title,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'target_chapters': targetChapters,
        'daily_questions': dailyQuestions,
      });

      await loadStudyPlans();
      return true;
    } catch (e) {
      _error = '创建学习计划失败';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWrongQuestions({int skip = 0, int limit = 20}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getWrongQuestions(skip: skip, limit: limit);
      _wrongQuestions = (res.data as List)
          .map((json) => WrongQuestion.fromJson(json))
          .toList();
      _error = null;
    } catch (e) {
      _error = '加载错题本失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateWrongReason(int wrongId, String reason) async {
    try {
      await _api.updateWrongReason(wrongId, reason);
      final index = _wrongQuestions.indexWhere((w) => w.id == wrongId);
      if (index != -1) {
        await loadWrongQuestions();
      }
      return true;
    } catch (e) {
      _error = '更新错因失败';
      return false;
    }
  }

  Future<bool> reviewWrongQuestion(int wrongId, bool isCorrect) async {
    try {
      await _api.reviewWrongQuestion(wrongId, isCorrect);
      await loadWrongQuestions();
      return true;
    } catch (e) {
      _error = '复习记录失败';
      return false;
    }
  }

  Future<void> loadTodayStats() async {
    try {
      final res = await _api.getTodayStats();
      _todayStats = StudyStats.fromJson(res.data);
      notifyListeners();
    } catch (e) {
      // 静默失败
    }
  }

  Future<void> loadStatsOverview() async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getStatsOverview();
      _overview = StatsOverview.fromJson(res.data);
      _error = null;
    } catch (e) {
      _error = '加载统计失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
