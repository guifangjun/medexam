// Basic Flutter widget test for MedExam App.

import 'package:flutter_test/flutter_test.dart';
import 'package:medexam/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MedExamApp());

    // Verify that the app title appears
    expect(find.text('MedExam AI'), findsOneWidget);
  });
}
