import 'package:flutter/material.dart';
import '../models/study.dart';
import '../services/api_service.dart';

class StudyProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<StudyPlan> _plans = [];
  DailyTask? _todayTask;
  List<WrongQuestion> _wrongQuestions = [];
  WrongReviewCalendar? _wrongReviewCalendar;
  WrongReviewPlan? _wrongReviewPlan;
  StudyStats? _todayStats;
  StatsOverview? _overview;
  StudyPrescription? _prescription;
  bool _isLoading = false;
  bool _isLoadingMoreWrongQuestions = false;
  bool _hasMoreWrongQuestions = true;
  String? _wrongQuestionExamCategory;
  static const int _wrongQuestionPageSize = 20;
  String? _error;

  List<StudyPlan> get plans => _plans;
  DailyTask? get todayTask => _todayTask;
  StudyPlan? get activePlan {
    for (final plan in _plans) {
      if (plan.isActive) return plan;
    }
    return _plans.isNotEmpty ? _plans.first : null;
  }

  StudyPlan? get todayTaskPlan {
    final taskPlanId = _todayTask?.planId;
    if (taskPlanId == null) return activePlan;
    for (final plan in _plans) {
      if (plan.id == taskPlanId) return plan;
    }
    return activePlan;
  }

  List<WrongQuestion> get wrongQuestions => _wrongQuestions;
  WrongReviewCalendar? get wrongReviewCalendar => _wrongReviewCalendar;
  WrongReviewPlan? get wrongReviewPlan => _wrongReviewPlan;
  StudyStats? get todayStats => _todayStats;
  StatsOverview? get overview => _overview;
  StudyPrescription? get prescription => _prescription;
  bool get isLoading => _isLoading;
  bool get isLoadingMoreWrongQuestions => _isLoadingMoreWrongQuestions;
  bool get hasMoreWrongQuestions => _hasMoreWrongQuestions;
  int get wrongQuestionTotalCount =>
      _wrongReviewCalendar?.totalWrong ?? _wrongQuestions.length;
  String? get error => _error;

  Future<void> loadTodayTask({String? examCategory}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getTodayTask(examCategory: examCategory);
      _todayTask = DailyTask.fromJson(res.data);
      _error = null;
    } catch (e) {
      _error = '加载今日任务失败';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStudyPlans({String? examCategory}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getStudyPlans(examCategory: examCategory);
      _plans =
          (res.data as List).map((json) => StudyPlan.fromJson(json)).toList();
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
    String? examCategory,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _api.createStudyPlan({
        'title': title,
        'plan_type': 'daily',
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'target_chapters': targetChapters,
        'daily_questions': dailyQuestions,
        if (examCategory != null && examCategory.isNotEmpty)
          'exam_category': examCategory,
      });

      await loadStudyPlans(examCategory: examCategory);
      await loadTodayTask(examCategory: examCategory);
      return true;
    } catch (e) {
      _error = '创建学习计划失败';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWrongQuestions({
    int skip = 0,
    int limit = _wrongQuestionPageSize,
    bool append = false,
    String? examCategory,
  }) async {
    try {
      if (!append) {
        _wrongQuestionExamCategory = examCategory;
      }
      final effectiveExamCategory = examCategory ?? _wrongQuestionExamCategory;
      if (append) {
        _isLoadingMoreWrongQuestions = true;
      } else {
        _isLoading = true;
      }
      notifyListeners();

      final res = await _api.getWrongQuestions(
        skip: skip,
        limit: limit,
        examCategory: effectiveExamCategory,
      );
      final page = (res.data as List)
          .map((json) => WrongQuestion.fromJson(json))
          .toList();
      if (append) {
        final existingIds = _wrongQuestions.map((item) => item.id).toSet();
        _wrongQuestions = [
          ..._wrongQuestions,
          ...page.where((item) => !existingIds.contains(item.id)),
        ];
      } else {
        _wrongQuestions = page;
        await loadWrongReviewCalendar(examCategory: effectiveExamCategory);
        await loadWrongReviewPlan(examCategory: effectiveExamCategory);
      }
      final total = _wrongReviewCalendar?.totalWrong;
      _hasMoreWrongQuestions =
          total == null ? page.length >= limit : _wrongQuestions.length < total;
      _error = null;
    } catch (e) {
      _error = '加载错题本失败';
    } finally {
      _isLoading = false;
      _isLoadingMoreWrongQuestions = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreWrongQuestions() async {
    if (_isLoadingMoreWrongQuestions || !_hasMoreWrongQuestions) return;
    await loadWrongQuestions(
      skip: _wrongQuestions.length,
      append: true,
      examCategory: _wrongQuestionExamCategory,
    );
  }

  Future<bool> updateWrongReason(int wrongId, String reason) async {
    try {
      await _api.updateWrongReason(wrongId, reason);
      final index = _wrongQuestions.indexWhere((w) => w.id == wrongId);
      if (index != -1) {
        await loadWrongQuestions(examCategory: _wrongQuestionExamCategory);
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
      await loadWrongQuestions(examCategory: _wrongQuestionExamCategory);
      return true;
    } catch (e) {
      _error = '复习记录失败';
      return false;
    }
  }

  Future<void> loadWrongReviewCalendar({
    int days = 14,
    String? examCategory,
  }) async {
    try {
      final res = await _api.getWrongReviewCalendar(
        days: days,
        examCategory: examCategory,
      );
      _wrongReviewCalendar = WrongReviewCalendar.fromJson(res.data);
      notifyListeners();
    } catch (e) {
      // 错题日历失败不影响错题本列表。
    }
  }

  Future<void> loadWrongReviewPlan({String? examCategory}) async {
    try {
      final res = await _api.getWrongReviewPlan(examCategory: examCategory);
      _wrongReviewPlan = WrongReviewPlan.fromJson(res.data);
      notifyListeners();
    } catch (e) {
      // 智能复盘失败不影响错题本列表。
    }
  }

  Future<void> loadTodayStats({String? examCategory}) async {
    try {
      final res = await _api.getTodayStats(examCategory: examCategory);
      _todayStats = StudyStats.fromJson(res.data);
      notifyListeners();
    } catch (e) {
      // 静默失败
    }
  }

  Future<void> loadPrescription({String? examCategory}) async {
    try {
      final res = await _api.getStudyPrescription(examCategory: examCategory);
      _prescription = StudyPrescription.fromJson(res.data);
      notifyListeners();
    } catch (e) {
      // 首页学习处方属于增强能力，失败时不影响基础学习入口。
    }
  }

  Future<void> loadStatsOverview({String? examCategory}) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getStatsOverview(examCategory: examCategory);
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

  void clearUserSession() {
    _plans = [];
    _todayTask = null;
    _wrongQuestions = [];
    _wrongReviewCalendar = null;
    _wrongReviewPlan = null;
    _todayStats = null;
    _overview = null;
    _prescription = null;
    _isLoading = false;
    _isLoadingMoreWrongQuestions = false;
    _hasMoreWrongQuestions = true;
    _wrongQuestionExamCategory = null;
    _error = null;
    notifyListeners();
  }
}
