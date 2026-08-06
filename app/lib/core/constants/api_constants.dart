class ApiConstants {
  // 后端 API 地址：
  // - 本地开发默认指向本机
  // - 公网构建时使用：flutter build web --dart-define=API_BASE_URL=https://your-api.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // API 端点
  static const String auth = '/api/auth';
  static const String register = '$auth/register';
  static const String login = '$auth/login';
  static const String me = '$auth/me';

  static const String questions = '/api/questions';
  static const String chapters = '$questions/chapters';
  static const String practice = '$questions/practice';
  static const String exam = '$questions/exam';
  static const String examCount = '$questions/exam/count';
  static const String examAttempts = '$questions/exam/attempts';
  static const String submit = '$questions/submit';
  static const String examSubmit = '$questions/exam/submit';

  static const String ai = '/api/ai';
  static const String chat = '$ai/chat';
  static const String aiHistory = '$ai/history';
  static const String aiSessions = '$ai/sessions';
  static const String aiCollections = '$ai/collections';

  static const String study = '/api/study';
  static const String studyPlan = '$study/plan';
  static const String todayTask = '$study/today';
  static const String wrong = '$study/wrong';
  static const String wrongCalendar = '$wrong/calendar';
  static const String wrongReviewPlan = '$wrong/review-plan';
  static const String statsToday = '$study/stats/today';
  static const String statsOverview = '$study/stats/overview';
  static const String studyPrescription = '$study/prescription';

  static const String admin = '/api/admin';
  static const String adminLogin = '$admin/auth/login';
  static const String adminMe = '$admin/auth/me';
  static const String adminDashboard = '$admin/dashboard';
  static const String adminExamCategories = '$admin/exam-categories';
  static const String adminQuestions = '$admin/questions';
  static const String adminCourses = '$admin/courses';
  static const String adminUsers = '$admin/users';
}

class AppConstants {
  // 用户备考目标/考试类别
  static const List<String> primaryExamCategories = [
    '执业资格',
    '初级职称',
    '中级职称',
    '高级职称'
  ];

  static const List<String> examCategories = [
    '临床执业医师',
    '临床助理医师',
    '中医执业医师',
    '中医助理医师',
    '口腔执业医师',
    '口腔助理医师',
    '中西医执业医师',
    '中西医助理医师',
    '乡村全科助理医师',
    '师承和确有专长',
    '中医医术确有专长',
    '公卫执业',
    '公卫助理',
    '执业西药师',
    '执业中药师',
    '护士执业资格',
    '国际护士（ISPN）',
  ];

  // 考试类型
  static const List<String> examTypes = ['执业医师', '助理医师'];

  static String normalizeExamCategory(String? value) {
    switch (value) {
      case '临床执业医师':
      case '临床助理医师':
      case '中医执业医师':
      case '中医助理医师':
      case '口腔执业医师':
      case '口腔助理医师':
      case '中西医执业医师':
      case '中西医助理医师':
      case '乡村全科助理医师':
      case '师承和确有专长':
      case '中医医术确有专长':
      case '公卫执业':
      case '公卫助理':
      case '执业西药师':
      case '执业中药师':
      case '护士执业资格':
      case '国际护士（ISPN）':
      case '初级职称':
      case '中级职称':
      case '高级职称':
        return value!;
      case '执业医师':
        return '临床执业医师';
      case '助理医师':
        return '临床助理医师';
      case '执业资格':
      default:
        return '临床执业医师';
    }
  }

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
