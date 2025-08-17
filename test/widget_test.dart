// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:hlvm_mobileapp/main.dart';

void main() {
  testWidgets('App should show login screen when not logged in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));

    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Логин'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
  });

  testWidgets('App should show home screen when logged in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: true));

    expect(find.text('Счета'), findsOneWidget);
    expect(find.text('Чеки'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });
}
