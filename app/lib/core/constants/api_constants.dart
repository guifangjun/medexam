class ApiConstants {
  // 后端 API 地址，开发环境指向本机
  static const String baseUrl = 'http://localhost:8000';

  // API 端点
  static const String auth = '/api/auth';
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String me = '$auth/me';

  static const String questions = '/api/questions';
  static const String chapters = '$questions/chapters';
  static const String practice = '$questions/practice';
  static const String exam = '$questions/exam';
  static const String submit = '$questions/submit';

  static const String ai = '/api/ai';
  static const String chat = '$ai/chat';
  static const String aiHistory = '$ai/history';
  static const String aiSessions = '$ai/sessions';

  static const String study = '/api/study';
  static const String studyPlan = '$study/plan';
  static const String todayTask = '$study/today';
  static const String wrong = '$study/wrong';
  static const String statsToday = '$study/stats/today';
  static const String statsOverview = '$study/stats/overview';
}

class AppConstants {
  // 考试类型
  static const List<String> examTypes = ['执业医师', '助理医师'];

  // 错因分类
  static const List<String> wrongReasons = [
    '粗心大意',
    '概念不清',
    '记忆模糊',
    '理解偏差',
    '其他',
  ];

  // 题目类型
  static const Map<String, String> questionTypes = {
    'single': '单选题',
    'multi': '多选题',
    'case': '病例题',
  };

  // 科目分类（按执业医师考试大纲）
  static const List<String> subjects = [
    '基础医学',
    '临床医学',
    '内科学',
    '外科学',
    '妇产科学',
    '儿科学',
    '预防医学',
  ];
}
