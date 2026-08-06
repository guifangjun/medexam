import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_messenger.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/exam_category_provider.dart';
import 'data/providers/question_provider.dart';
import 'data/providers/study_provider.dart';
import 'data/providers/ai_chat_provider.dart';
import 'presentation/screens/admin/admin_screen.dart';
import 'presentation/screens/home/home_screen.dart';

void main() {
  runApp(const MedExamApp());
}

class MedExamApp extends StatelessWidget {
  const MedExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => ExamCategoryProvider()..loadExamCategories(),
        ),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
        ChangeNotifierProvider(create: (_) => StudyProvider()),
        ChangeNotifierProvider(create: (_) => AIChatProvider()),
      ],
      child: MaterialApp(
        title: 'MedExam AI',
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/admin': (_) => const AdminScreen(),
        },
      ),
    );
  }
}
