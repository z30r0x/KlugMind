import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/widgets/page_top_bar.dart';
import 'package:klugmind/core/widgets/theme_button.dart';
import 'package:klugmind/core/widgets/theme_controller.dart';
import 'package:klugmind/features/profile_page/profile.dart';

void main() {
  tearDown(() => ThemeController.mode.value = ThemeMode.system);

  Widget wrap() => const MaterialApp(home: ProfilePage());

  Switch switchAt(WidgetTester t, int i) =>
      t.widget<Switch>(find.byType(Switch).at(i));

  testWidgets('renders avatar, name, subtitle and stats', (t) async {
    await t.pumpWidget(wrap());
    expect(find.text('JM'), findsOneWidget);
    expect(find.text('Jordan Marsh'), findsOneWidget);
    expect(find.text('Junior • 3 courses this semester'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('142'), findsOneWidget);
    expect(find.text('9.5h'), findsOneWidget);
    expect(find.text('DAY STREAK'), findsOneWidget);
    expect(find.text('CARDS REVIEWED'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
  });

  testWidgets('lists the courses and settings', (t) async {
    await t.pumpWidget(wrap());
    expect(find.text('Your courses'), findsOneWidget);
    expect(find.text('Organic Chemistry II'), findsOneWidget);
    expect(find.text('6h/wk'), findsOneWidget);
    expect(find.text('Linear Algebra'), findsOneWidget);
    expect(find.text('US History 1865–Present'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Study reminders'), findsOneWidget);
    expect(find.text('Weekly progress email'), findsOneWidget);
  });

  testWidgets('shows theme toggle (no step dots) and the 4-tab navbar',
      (t) async {
    await t.pumpWidget(wrap());
    expect(find.byType(PageTopBar), findsOneWidget);
    expect(find.byType(ThemeButton), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('dark mode switch drives ThemeController', (t) async {
    ThemeController.mode.value = ThemeMode.light;
    await t.pumpWidget(wrap());
    expect(switchAt(t, 0).value, isFalse);

    await t.ensureVisible(find.byType(Switch).first);
    await t.tap(find.byType(Switch).first);
    await t.pump();
    expect(ThemeController.mode.value, ThemeMode.dark);
    expect(switchAt(t, 0).value, isTrue);

    await t.tap(find.byType(Switch).first);
    await t.pump();
    expect(ThemeController.mode.value, ThemeMode.light);
    expect(switchAt(t, 0).value, isFalse);
  });

  testWidgets('theme icon and dark mode switch stay in sync', (t) async {
    ThemeController.mode.value = ThemeMode.light;
    await t.pumpWidget(wrap());
    expect(find.text('☀'), findsOneWidget);

    await t.tap(find.byType(ThemeButton));
    await t.pump();
    expect(find.text('☾'), findsOneWidget);
    expect(switchAt(t, 0).value, isTrue);
  });

  testWidgets('study reminders and weekly email switches toggle',
      (t) async {
    await t.pumpWidget(wrap());
    await t.ensureVisible(find.byType(Switch).at(1));
    expect(switchAt(t, 1).value, isTrue);
    await t.tap(find.byType(Switch).at(1));
    await t.pump();
    expect(switchAt(t, 1).value, isFalse);

    await t.ensureVisible(find.byType(Switch).at(2));
    await t.tap(find.byType(Switch).at(2));
    await t.pump();
    expect(switchAt(t, 2).value, isFalse);
  });
}