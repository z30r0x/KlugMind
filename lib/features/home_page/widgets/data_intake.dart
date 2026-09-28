// test/home_page_intake_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/features/home_page/home.dart';

void main() {
  Widget wrap() => const MaterialApp(home: HomePage());

  testWidgets('tapping Paste text opens a text-entry dialog', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Paste syllabus text'), findsOneWidget);
  });

  testWidgets('cancelling paste-text dialog does not show status chip',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pasted text saved'), findsNothing);
  });

  testWidgets('saving pasted text shows a status chip', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Week 1: intro. Exam Oct 5.');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pasted text saved'), findsOneWidget);
  });

  // File picker / camera plugin calls hit platform channels with no mock
  // registered in the default test binding — they throw MissingPluginException
  // in a plain widget test. Exercise only the try/catch surface here;
  // full integration coverage belongs in an integration_test target with
  // file_picker's/image_picker's platform mocks registered.
  testWidgets('file picker failure shows a SnackBar instead of crashing',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Upload PDF or photo'));
    await tester.pump(); // let the async call fail
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('camera failure shows a SnackBar instead of crashing',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Take a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SnackBar), findsOneWidget);
  });
}