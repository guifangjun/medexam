import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/chapter.dart';
import '../services/api_service.dart';

class QuestionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _useMockData = false; // 演示模式开关

  String _examCategory = '执业资格';
  String _practiceMode = 'chapter';
  String? _practiceTitle;
  int? _practiceChapterId;
  bool _practiceAttempted = false;
  String? _recentStudyTitle;
  String? _recentStudyAction;
  int? _recentChapterId;
  String? _recentStudyMode;
  String? _recentStudyTag;
  int _recentStudyLimit = 20;
  List<Chapter> _chapters = [];
  List<Question> _currentQuestions = [];
  int _currentIndex = 0;
  Question? _currentQuestion;
  SubmitResult? _lastResult;
  ExamResult? _examResult;
  List<ExamAttemptSummary> _examAttempts = [];
  int? _examAvailableCount;
  final Map<int, String> _examAnswers = {};
  bool _isLoading = false;
  String? _error;

  bool get useMockData => _useMockData;

  void setMockDataMode(bool enabled) {
    if (_useMockData == enabled) return;
    _useMockData = enabled;
    _chapters = [];
    _currentQuestions = [];
    _currentIndex = 0;
    _currentQuestion = null;
    _lastResult = null;
    _examResult = null;
    _examAnswers.clear();
    _examAttempts = [];
    _examAvailableCount = null;
    _practiceAttempted = false;
    _error = null;
    notifyListeners();
    loadChapters();
    loadExamAttempts();
    loadExamAvailability();
  }

  String get examCategory => _examCategory;
  String get practiceMode => _practiceMode;
  String? get practiceTitle => _practiceTitle;
  int? get practiceChapterId => _practiceChapterId;
  bool get practiceAttempted => _practiceAttempted;
  String? get recentStudyTitle => _recentStudyTitle;
  String? get recentStudyAction => _recentStudyAction;
  int? get recentChapterId => _recentChapterId;
  String? get recentStudyMode => _recentStudyMode;
  String? get recentStudyTag => _recentStudyTag;
  int get recentStudyLimit => _recentStudyLimit;
  List<Chapter> get chapters => _chapters;
  List<Question> get currentQuestions => _currentQuestions;
  int get currentIndex => _currentIndex;
  Question? get currentQuestion => _currentQuestion;
  SubmitResult? get lastResult => _lastResult;
  ExamResult? get examResult => _examResult;
  List<ExamAttemptSummary> get examAttempts => _examAttempts;
  int? get examAvailableCount => _examAvailableCount;
  Map<int, String> get examAnswers => Map.unmodifiable(_examAnswers);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasQuestions => _currentQuestions.isNotEmpty;
  bool get hasPracticeQuestions =>
      _currentQuestions.isNotEmpty && _practiceMode != 'exam';
  bool get hasExamQuestions =>
      _currentQuestions.isNotEmpty && _practiceMode == 'exam';
  bool get isLastQuestion => _currentIndex >= _currentQuestions.length - 1;

  double get progress {
    if (_currentQuestions.isEmpty) return 0;
    return (_currentIndex + 1) / _currentQuestions.length;
  }

  // 各考试类别的章节数据
  static final Map<String, List<Chapter>> _mockChaptersByCategory = {
    '执业资格': [
      Chapter(
          id: 1,
          name: '基础医学',
          order: 1,
          subjects: ['解剖学', '生理学', '病理学', '生物化学']),
      Chapter(
          id: 2,
          name: '临床医学',
          order: 2,
          subjects: ['内科学', '外科学', '妇产科学', '儿科学']),
      Chapter(
          id: 3, name: '预防医学', order: 3, subjects: ['流行病学', '统计学', '环境卫生学']),
      Chapter(id: 4, name: '医学人文', order: 4, subjects: ['医学伦理', '卫生法规']),
    ],
    '初级职称': [
      Chapter(
          id: 11, name: '临床基础知识', order: 1, subjects: ['生理学', '病理学', '药理学']),
      Chapter(
          id: 12, name: '专业理论与技能', order: 2, subjects: ['诊断学', '内科学', '外科学']),
      Chapter(
          id: 13, name: '常见病诊疗', order: 3, subjects: ['心血管疾病', '呼吸系统', '消化系统']),
    ],
    '中级职称': [
      Chapter(
          id: 21,
          name: '中级临床理论',
          order: 1,
          subjects: ['病理生理学', '分子生物学', '免疫学']),
      Chapter(
          id: 22, name: '专业进展', order: 2, subjects: ['新技术应用', '循证医学', '临床指南']),
      Chapter(id: 23, name: '疑难病例分析', order: 3, subjects: ['复杂病例', '多学科会诊']),
    ],
    '高级职称': [
      Chapter(id: 31, name: '学科前沿', order: 1, subjects: ['最新研究成果', '前沿技术']),
      Chapter(
          id: 32,
          name: '临床科研方法',
          order: 2,
          subjects: ['临床试验', '医学统计学', '论文写作']),
      Chapter(id: 33, name: '医学教育', order: 3, subjects: ['教学能力', '继续教育']),
    ],
  };

  // 各章节的模拟题目
  static final Map<int, List<Question>> _mockQuestionsByChapter = {
    // 执业资格 - 基础医学
    1: [
      Question(
          id: 101,
          chapterId: 1,
          questionType: 'single',
          content: '心脏的位置位于（）',
          options: {'A': '胸腔中部偏左', 'B': '胸腔中部偏右', 'C': '腹腔上部', 'D': '纵隔中部'},
          answer: 'A',
          difficulty: 1,
          isRealExam: false,
          tags: ['解剖学', '心脏'],
          createdAt: DateTime.now()),
      Question(
          id: 102,
          chapterId: 1,
          questionType: 'single',
          content: '正常成年人的心率范围是（）',
          options: {
            'A': '40-60次/分',
            'B': '60-100次/分',
            'C': '100-120次/分',
            'D': '50-80次/分'
          },
          answer: 'B',
          difficulty: 1,
          isRealExam: false,
          tags: ['生理学', '心率'],
          createdAt: DateTime.now()),
    ],
    // 执业资格 - 临床医学
    2: [
      Question(
          id: 201,
          chapterId: 2,
          questionType: 'single',
          content: '高血压的诊断标准是收缩压≥（）mmHg',
          options: {'A': '120', 'B': '130', 'C': '140', 'D': '150'},
          answer: 'C',
          difficulty: 2,
          isRealExam: true,
          examYear: 2023,
          tags: ['内科学', '高血压'],
          createdAt: DateTime.now()),
      Question(
          id: 202,
          chapterId: 2,
          questionType: 'single',
          content: '下列哪项是急性心肌梗死的典型胸痛特点（）',
          options: {'A': '针刺样疼痛', 'B': '压榨性闷痛', 'C': '烧灼样疼痛', 'D': '隐痛'},
          answer: 'B',
          difficulty: 2,
          isRealExam: true,
          examYear: 2023,
          tags: ['内科学', '心肌梗死'],
          createdAt: DateTime.now()),
    ],
    // 执业资格 - 预防医学
    3: [
      Question(
          id: 301,
          chapterId: 3,
          questionType: 'single',
          content: '流行病学研究的目的是（）',
          options: {'A': '控制疾病发生', 'B': '仅描述疾病分布', 'C': '仅研究病因', 'D': '仅进行诊断'},
          answer: 'A',
          difficulty: 1,
          isRealExam: false,
          tags: ['流行病学'],
          createdAt: DateTime.now()),
    ],
    // 执业资格 - 医学人文
    4: [
      Question(
          id: 401,
          chapterId: 4,
          questionType: 'single',
          content: '医学伦理学的核心原则是（）',
          options: {'A': '知情同意', 'B': '有利原则', 'C': '公正原则', 'D': '以上都是'},
          answer: 'D',
          difficulty: 1,
          isRealExam: false,
          tags: ['医学伦理'],
          createdAt: DateTime.now()),
    ],
    // 初级职称
    11: [
      Question(
          id: 1101,
          chapterId: 11,
          questionType: 'single',
          content: '糖酵解途径中最重要的限速酶是（）',
          options: {'A': '己糖激酶', 'B': '磷酸果糖激酶-1', 'C': '丙酮酸激酶', 'D': '乳酸脱氢酶'},
          answer: 'B',
          difficulty: 2,
          isRealExam: false,
          tags: ['生物化学', '糖代谢'],
          createdAt: DateTime.now()),
    ],
    12: [
      Question(
          id: 1201,
          chapterId: 12,
          questionType: 'single',
          content: '下列哪项体征提示心力衰竭（）',
          options: {'A': '双肺湿啰音', 'B': '双肺干啰音', 'C': '肺野清晰', 'D': '语颤增强'},
          answer: 'A',
          difficulty: 2,
          isRealExam: false,
          tags: ['诊断学', '心力衰竭'],
          createdAt: DateTime.now()),
    ],
    13: [
      Question(
          id: 1301,
          chapterId: 13,
          questionType: 'single',
          content: '社区获得性肺炎最常见的病原体是（）',
          options: {'A': '肺炎链球菌', 'B': '支原体', 'C': '病毒', 'D': '真菌'},
          answer: 'A',
          difficulty: 2,
          isRealExam: false,
          tags: ['呼吸系统', '肺炎'],
          createdAt: DateTime.now()),
    ],
    // 中级职称
    21: [
      Question(
          id: 2101,
          chapterId: 21,
          questionType: 'single',
          content: '凋亡与坏死的最主要区别是（）',
          options: {'A': '细胞膜完整性', 'B': '能量需求', 'C': '细胞器完整性', 'D': '炎症反应'},
          answer: 'D',
          difficulty: 3,
          isRealExam: false,
          tags: ['病理学', '细胞死亡'],
          createdAt: DateTime.now()),
    ],
    22: [
      Question(
          id: 2201,
          chapterId: 22,
          questionType: 'single',
          content: '循证医学的核心是（）',
          options: {'A': '个人经验', 'B': '最佳证据', 'C': '权威观点', 'D': '传统方法'},
          answer: 'B',
          difficulty: 2,
          isRealExam: false,
          tags: ['循证医学'],
          createdAt: DateTime.now()),
    ],
    23: [
      Question(
          id: 2301,
          chapterId: 23,
          questionType: 'case',
          content: '男性，65岁，突发胸痛2小时伴大汗。最可能的诊断是（）',
          options: {'A': '主动脉夹层', 'B': '急性心肌梗死', 'C': '肺栓塞', 'D': '气胸'},
          answer: 'B',
          difficulty: 3,
          isRealExam: false,
          tags: ['内科学', '急诊'],
          createdAt: DateTime.now()),
    ],
    // 高级职称
    31: [
      Question(
          id: 3101,
          chapterId: 31,
          questionType: 'single',
          content: 'CRISPR-Cas9技术主要用于（）',
          options: {'A': '基因编辑', 'B': '蛋白质合成', 'C': '药物研发', 'D': '疾病诊断'},
          answer: 'A',
          difficulty: 3,
          isRealExam: false,
          tags: ['分子生物学', '基因工程'],
          createdAt: DateTime.now()),
    ],
    32: [
      Question(
          id: 3201,
          chapterId: 32,
          questionType: 'single',
          content: '随机对照试验中，双盲法是指（）',
          options: {
            'A': '研究者和受试者均不知分组情况',
            'B': '仅受试者不知分组情况',
            'C': '仅研究者不知分组情况',
            'D': '双方都知道分组'
          },
          answer: 'A',
          difficulty: 2,
          isRealExam: false,
          tags: ['医学统计学', '临床试验'],
          createdAt: DateTime.now()),
    ],
    33: [
      Question(
          id: 3301,
          chapterId: 33,
          questionType: 'single',
          content: '医学教育的核心能力包括（）',
          options: {'A': '教学能力', 'B': '科研能力', 'C': '临床能力', 'D': '以上都是'},
          answer: 'D',
          difficulty: 1,
          isRealExam: false,
          tags: ['医学教育'],
          createdAt: DateTime.now()),
    ],
  };

  void setExamCategory(String category) {
    if (_examCategory != category) {
      _examCategory = category;
      _chapters = [];
      _currentQuestions = [];
      _currentIndex = 0;
      _currentQuestion = null;
      _lastResult = null;
      _examResult = null;
      _examAnswers.clear();
      _examAttempts = [];
      _examAvailableCount = null;
      _practiceMode = 'chapter';
      _practiceTitle = null;
      _practiceChapterId = null;
      _practiceAttempted = false;
      _recentStudyTitle = null;
      _recentStudyAction = null;
      _recentChapterId = null;
      _recentStudyMode = null;
      _recentStudyTag = null;
      _recentStudyLimit = 20;
      _error = null;
      notifyListeners();
      loadChapters();
      loadExamAttempts();
      loadExamAvailability();
    }
  }

  Future<void> loadChapters() async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.getChapters(
        examCategory: _examCategory,
        onlyWithQuestions: !_useMockData,
      );
      _chapters =
          (res.data as List).map((json) => Chapter.fromJson(json)).toList();
      if (_chapters.isEmpty && _useMockData) {
        _chapters = _mockChaptersByCategory[_examCategory] ?? [];
      }
      _error = _chapters.isEmpty ? '暂无题目' : null;
    } catch (e) {
      if (_useMockData) {
        _chapters = _mockChaptersByCategory[_examCategory] ?? [];
        _error = null;
      } else {
        _chapters = [];
        _error = '章节加载失败，请稍后重试';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPracticeQuestions({
    int? chapterId,
    List<int>? questionIds,
    int? difficulty,
    String mode = 'chapter',
    String? tag,
    String? title,
    int limit = 20,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _api.getPracticeQuestions(
        chapterId: chapterId,
        questionIds: questionIds,
        examCategory: _examCategory,
        difficulty: difficulty,
        mode: mode,
        tag: tag,
        limit: limit,
      );
      _currentQuestions =
          (res.data as List).map((json) => Question.fromJson(json)).toList();
      _currentIndex = 0;
      _lastResult = null;
      _examResult = null;
      _examAnswers.clear();
      _currentQuestion =
          _currentQuestions.isNotEmpty ? _currentQuestions.first : null;
      _error = _currentQuestions.isEmpty ? '暂无题目' : null;
      _practiceMode = mode;
      _practiceTitle = title ?? _modeTitle(mode, tag: tag);
      _practiceChapterId = chapterId;
      _practiceAttempted = true;
      _recentStudyTitle = _practiceTitle;
      _recentStudyAction = _currentQuestions.isEmpty
          ? '回到${_practiceTitle ?? "练习"}'
          : '继续${_practiceTitle ?? "刷题"}';
      _recentChapterId = chapterId;
      _recentStudyMode = mode;
      _recentStudyTag = tag;
      _recentStudyLimit = limit;
      if (_currentQuestions.isNotEmpty) {
        _error = null;
      }
    } catch (e) {
      if (_useMockData) {
        _loadMockPracticeQuestions(
          chapterId: chapterId,
          questionIds: questionIds,
          mode: mode,
          tag: tag,
          title: title ?? _modeTitle(mode, tag: tag),
          limit: limit,
        );
        _error = null;
      } else {
        _currentQuestions = [];
        _currentQuestion = null;
        _lastResult = null;
        _examResult = null;
        _examAnswers.clear();
        _error = '题目加载失败，请稍后重试';
        _practiceMode = mode;
        _practiceTitle = title ?? _modeTitle(mode, tag: tag);
        _practiceChapterId = chapterId;
        _practiceAttempted = true;
        _recentStudyTitle = _practiceTitle;
        _recentStudyAction = '重试${_practiceTitle ?? "练习"}';
        _recentChapterId = chapterId;
        _recentStudyMode = mode;
        _recentStudyTag = tag;
        _recentStudyLimit = limit;
      }
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

      final res = await _api.getExamQuestions(
        count: count,
        examCategory: _examCategory,
      );
      _currentQuestions =
          (res.data as List).map((json) => Question.fromJson(json)).toList();
      _currentIndex = 0;
      _lastResult = null;
      _examResult = null;
      _examAnswers.clear();
      _currentQuestion =
          _currentQuestions.isNotEmpty ? _currentQuestions.first : null;
      _practiceMode = 'exam';
      _practiceTitle = '${_examCategory}模考';
      _practiceAttempted = false;
      if (_currentQuestions.isEmpty) {
        _error = '当前考试目标暂无可用模考题，请先在后台添加真题';
      } else if (_currentQuestions.length < count) {
        _error = '当前仅有 ${_currentQuestions.length} 道可用模考题，已按实际题量开考';
      } else {
        _error = null;
      }
    } catch (e) {
      if (_useMockData) {
        _loadMockExamQuestions(count);
        _error = null;
      } else {
        _currentQuestions = [];
        _currentQuestion = null;
        _lastResult = null;
        _examResult = null;
        _examAnswers.clear();
        _practiceMode = 'exam';
        _practiceTitle = '${_examCategory}模考';
        _practiceAttempted = false;
        _error = '模考题加载失败，请稍后重试';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadExamAvailability() async {
    if (_useMockData) {
      final chapters = _mockChaptersByCategory[_examCategory] ?? [];
      _examAvailableCount = chapters.fold<int>(
        0,
        (sum, chapter) =>
            sum + (_mockQuestionsByChapter[chapter.id]?.length ?? 0),
      );
      notifyListeners();
      return;
    }
    try {
      final res = await _api.getExamQuestionCount(examCategory: _examCategory);
      _examAvailableCount = res.data['count'] ?? 0;
      notifyListeners();
    } catch (e) {
      _examAvailableCount = null;
      notifyListeners();
    }
  }

  void _loadMockPracticeQuestions({
    int? chapterId,
    List<int>? questionIds,
    String mode = 'chapter',
    String? tag,
    String? title,
    int limit = 20,
  }) {
    if (questionIds != null && questionIds.isNotEmpty) {
      final allQuestions =
          _mockQuestionsByChapter.values.expand((item) => item);
      final idSet = questionIds.toSet();
      _currentQuestions = allQuestions
          .where((question) => idSet.contains(question.id))
          .toList();
    } else if (chapterId != null) {
      _currentQuestions = _mockQuestionsByChapter[chapterId] ?? [];
    } else {
      final chapters = _mockChaptersByCategory[_examCategory] ?? [];
      _currentQuestions = [];
      for (final chapter in chapters) {
        _currentQuestions.addAll(_mockQuestionsByChapter[chapter.id] ?? []);
      }
      if (_currentQuestions.length > limit) {
        _currentQuestions = _currentQuestions.take(limit).toList();
      }
    }
    _currentIndex = 0;
    _lastResult = null;
    _examResult = null;
    _examAnswers.clear();
    _currentQuestion =
        _currentQuestions.isNotEmpty ? _currentQuestions.first : null;
    _practiceMode = mode;
    _practiceTitle = title ?? _modeTitle(mode);
    _practiceChapterId = chapterId;
    _practiceAttempted = true;
    _recentStudyTitle = _practiceTitle;
    _recentStudyAction = _currentQuestions.isEmpty
        ? '回到${_practiceTitle ?? "练习"}'
        : '继续${_practiceTitle ?? "刷题"}';
    _recentChapterId = chapterId;
    _recentStudyMode = mode;
    _recentStudyTag = tag;
    _recentStudyLimit = limit;
  }

  String _modeTitle(String mode, {String? tag}) {
    switch (mode) {
      case 'unanswered':
        return '未做题练习';
      case 'wrong':
        return '错题复习';
      case 'tag':
        return tag == null || tag.isEmpty ? '高频考点' : '$tag 高频考点';
      case 'random':
        return '随机练习';
      default:
        return '章节练习';
    }
  }

  void _loadMockExamQuestions(int count) {
    final chapters = _mockChaptersByCategory[_examCategory] ?? [];
    _currentQuestions = [];
    for (final chapter in chapters) {
      _currentQuestions.addAll(_mockQuestionsByChapter[chapter.id] ?? []);
    }
    _currentQuestions.shuffle();
    if (_currentQuestions.length > count) {
      _currentQuestions = _currentQuestions.take(count).toList();
    }
    _currentIndex = 0;
    _lastResult = null;
    _examResult = null;
    _examAnswers.clear();
    _currentQuestion =
        _currentQuestions.isNotEmpty ? _currentQuestions.first : null;
    _practiceAttempted = false;
  }

  void selectExamAnswer(String selectedAnswer) {
    if (_currentQuestion == null || _examResult != null) return;
    _examAnswers[_currentQuestion!.id] = selectedAnswer;
    notifyListeners();
  }

  Future<ExamResult?> submitExam({required int timeSpent}) async {
    if (_currentQuestions.isEmpty) return null;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _api.submitExam({
        'time_spent': timeSpent,
        'answers': _currentQuestions
            .map((question) => {
                  'question_id': question.id,
                  'selected_answer': _examAnswers[question.id],
                })
            .toList(),
      });
      _examResult = ExamResult.fromJson(res.data);
      await loadExamAttempts();
      notifyListeners();
      return _examResult;
    } catch (e) {
      _error = '交卷失败，请确认登录状态后重试';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadExamAttempts({int skip = 0, int limit = 20}) async {
    try {
      final res = await _api.getExamAttempts(
        skip: skip,
        limit: limit,
        examCategory: _examCategory,
      );
      _examAttempts = (res.data as List)
          .map((item) => ExamAttemptSummary.fromJson(item))
          .toList();
      notifyListeners();
    } catch (e) {
      // 历史记录加载失败不影响开始模考。
    }
  }

  Future<ExamResult?> loadExamAttempt(int attemptId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final res = await _api.getExamAttempt(attemptId);
      _examResult = ExamResult.fromJson(res.data);
      _currentQuestions = [];
      _currentQuestion = null;
      _examAnswers.clear();
      notifyListeners();
      return _examResult;
    } catch (e) {
      _error = '加载模考报告失败';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SubmitResult?> submitAnswer(
    String selectedAnswer, {
    int timeSpent = 0,
  }) async {
    if (_currentQuestion == null) return null;

    // 演示模式：使用本地验证
    if (_useMockData) {
      final isCorrect = selectedAnswer.toUpperCase() ==
          _currentQuestion!.answer.toUpperCase();
      _lastResult = SubmitResult(
        isCorrect: isCorrect,
        correctAnswer: _currentQuestion!.answer,
        selectedAnswer: selectedAnswer,
        explanation: _currentQuestion!.explanation ??
            '本题考察${_currentQuestion!.tags.join("、")}相关知识点',
      );
      notifyListeners();
      return _lastResult;
    }

    // 正式模式：调用后端 API
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.submitQuestion({
        'question_id': _currentQuestion!.id,
        'selected_answer': selectedAnswer,
        'time_spent': timeSpent,
      });
      _lastResult = SubmitResult.fromJson(res.data);
      _lastResult = SubmitResult(
        isCorrect: _lastResult!.isCorrect,
        correctAnswer: _lastResult!.correctAnswer,
        selectedAnswer: selectedAnswer,
        explanation: _lastResult!.explanation,
        wrongReason: _lastResult!.wrongReason,
      );
      notifyListeners();
      return _lastResult;
    } catch (e) {
      _lastResult = null;
      _error = '提交失败，请检查网络或登录状态后重试';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void nextQuestion() {
    if (_currentIndex < _currentQuestions.length - 1) {
      _currentIndex++;
      _currentQuestion = _currentQuestions[_currentIndex];
      _lastResult = null;
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
    _examResult = null;
    _examAnswers.clear();
    _practiceChapterId = null;
    _practiceAttempted = false;
    _practiceMode = 'chapter';
    _practiceTitle = null;
    _error = null;
    notifyListeners();
  }

  void clearUserSession() {
    _chapters = [];
    _currentQuestions = [];
    _currentIndex = 0;
    _currentQuestion = null;
    _lastResult = null;
    _examResult = null;
    _examAttempts = [];
    _examAnswers.clear();
    _practiceChapterId = null;
    _practiceAttempted = false;
    _practiceMode = 'chapter';
    _practiceTitle = null;
    _recentStudyTitle = null;
    _recentStudyAction = null;
    _recentChapterId = null;
    _recentStudyMode = null;
    _recentStudyTag = null;
    _recentStudyLimit = 20;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
