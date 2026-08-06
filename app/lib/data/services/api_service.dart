import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _token;
  String? _adminToken;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    webOptions: WebOptions(
      dbName: 'MedExamSecureStorage',
      publicKey: 'MedExamPublicKey',
    ),
  );

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.path.startsWith(ApiConstants.admin)) {
          if (options.extra['skipAdminAuth'] == true) {
            return handler.next(options);
          }
          if (_adminToken == null) {
            return handler.next(options);
          }
          options.headers['Authorization'] = 'Bearer $_adminToken';
        } else if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          if (error.requestOptions.path.startsWith(ApiConstants.admin)) {
            clearAdminToken();
          } else {
            clearToken();
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> loadToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('access_token');
    } else {
      _token = await _secureStorage.read(key: 'access_token');
    }
  }

  Future<void> setToken(String token) async {
    _token = token;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
    } else {
      await _secureStorage.write(key: 'access_token', value: token);
    }
  }

  Future<void> clearToken() async {
    _token = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
    } else {
      await _secureStorage.delete(key: 'access_token');
    }
  }

  bool get hasToken => _token != null;

  Future<void> loadAdminToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _adminToken = prefs.getString('admin_access_token');
    } else {
      _adminToken = await _secureStorage.read(key: 'admin_access_token');
    }
  }

  Future<void> setAdminToken(String token) async {
    _adminToken = token;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_access_token', token);
    } else {
      await _secureStorage.write(key: 'admin_access_token', value: token);
    }
  }

  Future<void> clearAdminToken() async {
    _adminToken = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_access_token');
    } else {
      await _secureStorage.delete(key: 'admin_access_token');
    }
  }

  bool get hasAdminToken => _adminToken != null;

  // ============ Auth ============

  Future<Response> register(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.register, data: data);
  }

  Future<Response> sendSmsCode(String phone, {String purpose = 'login'}) async {
    return _dio.post('/api/auth/sms-code', data: {
      'phone': phone,
      'purpose': purpose,
    });
  }

  Future<Response> login(String username, String password) async {
    return _dio.post(
      ApiConstants.login,
      data: {
        'username': username,
        'password': password,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  Future<Response> loginWithSms(String phone, String smsCode) async {
    return _dio.post('/api/auth/login/sms', data: {
      'phone': phone,
      'sms_code': smsCode,
    });
  }

  Future<Response> getMe() async {
    return _dio.get(ApiConstants.me);
  }

  Future<Response> adminLogin(String username, String password) async {
    return _dio.post(
      ApiConstants.adminLogin,
      data: {
        'username': username,
        'password': password,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  Future<Response> getAdminMe() async {
    return _dio.get(ApiConstants.adminMe);
  }

  Future<Response> getAdminDashboard({
    String? examCategory,
    String? date,
  }) async {
    return _dio.get(ApiConstants.adminDashboard, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (date != null && date.isNotEmpty) 'date': date,
    });
  }

  Future<Response> getAdminExamCategories({
    bool includeInactive = true,
  }) async {
    return _dio.get(ApiConstants.adminExamCategories, queryParameters: {
      'include_inactive': includeInactive,
    });
  }

  Future<Response> getExamCategories() async {
    return _dio.get(ApiConstants.adminExamCategories, queryParameters: {
      'include_inactive': false,
    });
  }

  Future<Response> createAdminExamCategory(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.adminExamCategories, data: data);
  }

  Future<Response> updateAdminExamCategory(
      int categoryId, Map<String, dynamic> data) async {
    return _dio.put('${ApiConstants.adminExamCategories}/$categoryId',
        data: data);
  }

  Future<Response> deleteAdminExamCategory(int categoryId) async {
    return _dio.delete('${ApiConstants.adminExamCategories}/$categoryId');
  }

  Future<Response> updateMe(Map<String, dynamic> data) async {
    return _dio.put(ApiConstants.me, data: data);
  }

  // ============ Questions ============

  Future<Response> getChapters({
    String? examCategory,
    bool onlyWithQuestions = false,
  }) async {
    return _dio.get(ApiConstants.chapters, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (onlyWithQuestions) 'only_with_questions': true,
    });
  }

  Future<Response> getPracticeQuestions({
    int? chapterId,
    List<int>? questionIds,
    String? examCategory,
    int? difficulty,
    String mode = 'chapter',
    String? tag,
    int limit = 20,
  }) async {
    return _dio.get(ApiConstants.practice, queryParameters: {
      if (chapterId != null) 'chapter_id': chapterId,
      if (questionIds != null && questionIds.isNotEmpty)
        'question_ids': questionIds.join(','),
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (difficulty != null) 'difficulty': difficulty,
      'mode': mode,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      'limit': limit,
    });
  }

  Future<Response> getExamQuestions({
    int count = 50,
    String? examCategory,
  }) async {
    return _dio.get(ApiConstants.exam, queryParameters: {
      'count': count,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getExamQuestionCount({String? examCategory}) async {
    return _dio.get(ApiConstants.examCount, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> submitQuestion(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.submit, data: data);
  }

  Future<Response> submitExam(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.examSubmit, data: data);
  }

  Future<Response> getExamAttempts({
    int skip = 0,
    int limit = 20,
    String? examCategory,
  }) async {
    return _dio.get(ApiConstants.examAttempts, queryParameters: {
      'skip': skip,
      'limit': limit,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getExamAttempt(int attemptId) async {
    return _dio.get('${ApiConstants.examAttempts}/$attemptId');
  }

  // ============ Admin ============

  Future<Response> getAdminQuestions({
    String? keyword,
    String? examCategory,
    int? chapterId,
  }) async {
    return _dio.get(ApiConstants.adminQuestions, queryParameters: {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (chapterId != null) 'chapter_id': chapterId,
    });
  }

  Future<Response> createAdminQuestion(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.adminQuestions, data: data);
  }

  Future<Response> updateAdminQuestion(
      int questionId, Map<String, dynamic> data) async {
    return _dio.put('${ApiConstants.adminQuestions}/$questionId', data: data);
  }

  Future<Response> deleteAdminQuestion(int questionId) async {
    return _dio.delete('${ApiConstants.adminQuestions}/$questionId');
  }

  Future<Response> getAdminCourses({
    String? courseType,
    String? examCategory,
    bool? unlinkedOnly,
  }) async {
    return _dio.get(ApiConstants.adminCourses, queryParameters: {
      if (courseType != null && courseType.isNotEmpty)
        'course_type': courseType,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (unlinkedOnly != null) 'unlinked_only': unlinkedOnly,
    });
  }

  Future<Response> getPublishedCourses({
    String? courseType,
    String? examCategory,
  }) async {
    return _dio.get(ApiConstants.adminCourses,
        queryParameters: {
          if (courseType != null && courseType.isNotEmpty)
            'course_type': courseType,
          if (examCategory != null && examCategory.isNotEmpty)
            'exam_category': examCategory,
        },
        options: Options(extra: {'skipAdminAuth': true}));
  }

  Future<Response> createAdminCourse(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.adminCourses, data: data);
  }

  Future<Response> updateAdminCourse(
      int courseId, Map<String, dynamic> data) async {
    return _dio.put('${ApiConstants.adminCourses}/$courseId', data: data);
  }

  Future<Response> deleteAdminCourse(int courseId) async {
    return _dio.delete('${ApiConstants.adminCourses}/$courseId');
  }

  Future<Response> getAdminUsers({
    String? keyword,
    String? examCategory,
    bool? isActive,
  }) async {
    return _dio.get(ApiConstants.adminUsers, queryParameters: {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (isActive != null) 'is_active': isActive,
    });
  }

  Future<Response> createAdminUser(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.adminUsers, data: data);
  }

  Future<Response> updateAdminUser(
      int userId, Map<String, dynamic> data) async {
    return _dio.put('${ApiConstants.adminUsers}/$userId', data: data);
  }

  Future<Response> deleteAdminUser(int userId) async {
    return _dio.delete('${ApiConstants.adminUsers}/$userId');
  }

  // ============ AI Chat ============

  Future<Response> sendChat({
    required String content,
    String? sessionId,
    String? examCategory,
    int? relatedQuestionId,
  }) async {
    return _dio.post(ApiConstants.chat, data: {
      'content': content,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
      if (relatedQuestionId != null) 'related_question_id': relatedQuestionId,
    });
  }

  Future<Response> getChatHistory(String sessionId, {int limit = 20}) async {
    return _dio.get(ApiConstants.aiHistory, queryParameters: {
      'session_id': sessionId,
      'limit': limit,
    });
  }

  Future<Response> getChatSessions({String? examCategory}) async {
    return _dio.get(ApiConstants.aiSessions, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getChatCollections({
    int limit = 50,
    String? examCategory,
  }) async {
    return _dio.get(ApiConstants.aiCollections, queryParameters: {
      'limit': limit,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> collectMessage(int messageId) async {
    return _dio.post('${ApiConstants.ai}/$messageId/collect');
  }

  Future<Response> getAIStudyAdvice(Map<String, dynamic> data) async {
    return _dio.post('${ApiConstants.ai}/study-advice', data: data);
  }

  Future<Response> getAIWrongExplain(Map<String, dynamic> data) async {
    return _dio.post('${ApiConstants.ai}/wrong-explain', data: data);
  }

  Future<Response> getAIExamReport(Map<String, dynamic> data) async {
    return _dio.post('${ApiConstants.ai}/exam-report', data: data);
  }

  Future<Response> getAILearningPath(Map<String, dynamic> data) async {
    return _dio.post('${ApiConstants.ai}/learning-path', data: data);
  }

  // ============ Study ============

  Future<Response> createStudyPlan(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.studyPlan, data: data);
  }

  Future<Response> getStudyPlans({String? examCategory}) async {
    return _dio.get(ApiConstants.studyPlan, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getTodayTask({String? examCategory}) async {
    return _dio.get(ApiConstants.todayTask, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getWrongQuestions({
    int skip = 0,
    int limit = 20,
    String? examCategory,
  }) async {
    return _dio.get(ApiConstants.wrong, queryParameters: {
      'skip': skip,
      'limit': limit,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getWrongReviewCalendar({
    int days = 14,
    String? examCategory,
  }) async {
    return _dio.get(ApiConstants.wrongCalendar, queryParameters: {
      'days': days,
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getWrongReviewPlan({String? examCategory}) async {
    return _dio.get(ApiConstants.wrongReviewPlan, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> updateWrongReason(int wrongId, String reason) async {
    return _dio.put('${ApiConstants.wrong}/$wrongId/reason', data: {
      'wrong_reason': reason,
    });
  }

  Future<Response> reviewWrongQuestion(int wrongId, bool isCorrect) async {
    return _dio.post('${ApiConstants.wrong}/$wrongId/review', queryParameters: {
      'is_correct': isCorrect,
    });
  }

  Future<Response> getTodayStats({String? examCategory}) async {
    return _dio.get(ApiConstants.statsToday, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getStudyPrescription({String? examCategory}) async {
    return _dio.get(ApiConstants.studyPrescription, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }

  Future<Response> getStatsOverview({String? examCategory}) async {
    return _dio.get(ApiConstants.statsOverview, queryParameters: {
      if (examCategory != null && examCategory.isNotEmpty)
        'exam_category': examCategory,
    });
  }
}
