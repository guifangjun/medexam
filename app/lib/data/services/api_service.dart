import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;

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
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token 过期，清理存储
          _storage.delete(key: 'access_token');
          _token = null;
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> loadToken() async {
    _token = await _storage.read(key: 'access_token');
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'access_token');
  }

  bool get hasToken => _token != null;

  // ============ Auth ============

  Future<Response> register(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.register, data: data);
  }

  Future<Response> login(String username, String password) async {
    return _dio.post(
      ApiConstants.login,
      data: FormData.fromMap({
        'username': username,
        'password': password,
      }),
    );
  }

  Future<Response> getMe() async {
    return _dio.get(ApiConstants.me);
  }

  Future<Response> updateMe(Map<String, dynamic> data) async {
    return _dio.put(ApiConstants.me, data: data);
  }

  // ============ Questions ============

  Future<Response> getChapters() async {
    return _dio.get(ApiConstants.chapters);
  }

  Future<Response> getPracticeQuestions({
    int? chapterId,
    int? difficulty,
    int limit = 20,
  }) async {
    return _dio.get(ApiConstants.practice, queryParameters: {
      if (chapterId != null) 'chapter_id': chapterId,
      if (difficulty != null) 'difficulty': difficulty,
      'limit': limit,
    });
  }

  Future<Response> getExamQuestions({int count = 50}) async {
    return _dio.get(ApiConstants.exam, queryParameters: {
      'question_count': count,
    });
  }

  Future<Response> submitQuestion(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.submit, data: data);
  }

  // ============ AI Chat ============

  Future<Response> sendChat({
    required String content,
    int? relatedQuestionId,
  }) async {
    return _dio.post(ApiConstants.chat, data: {
      'content': content,
      if (relatedQuestionId != null) 'related_question_id': relatedQuestionId,
    });
  }

  Future<Response> getChatHistory(String sessionId, {int limit = 20}) async {
    return _dio.get(ApiConstants.aiHistory, queryParameters: {
      'session_id': sessionId,
      'limit': limit,
    });
  }

  Future<Response> getChatSessions() async {
    return _dio.get(ApiConstants.aiSessions);
  }

  Future<Response> collectMessage(int messageId) async {
    return _dio.post('${ApiConstants.ai}/$messageId/collect');
  }

  // ============ Study ============

  Future<Response> createStudyPlan(Map<String, dynamic> data) async {
    return _dio.post(ApiConstants.studyPlan, data: data);
  }

  Future<Response> getStudyPlans() async {
    return _dio.get(ApiConstants.studyPlan);
  }

  Future<Response> getTodayTask() async {
    return _dio.get(ApiConstants.todayTask);
  }

  Future<Response> getWrongQuestions({int skip = 0, int limit = 20}) async {
    return _dio.get(ApiConstants.wrong, queryParameters: {
      'skip': skip,
      'limit': limit,
    });
  }

  Future<Response> updateWrongReason(int wrongId, String reason) async {
    return _dio.put('${ApiConstants.wrong}/$wrongId/reason', data: {
      'wrong_reason': reason,
    });
  }

  Future<Response> reviewWrongQuestion(int wrongId, bool isCorrect) async {
    return _dio.post('${ApiConstants.wrong}/$wrongId/review', data: {
      'is_correct': isCorrect,
    });
  }

  Future<Response> getTodayStats() async {
    return _dio.get(ApiConstants.statsToday);
  }

  Future<Response> getStatsOverview() async {
    return _dio.get(ApiConstants.statsOverview);
  }
}
