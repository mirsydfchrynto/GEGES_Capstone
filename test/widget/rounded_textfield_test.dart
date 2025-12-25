import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';

void main() {
  testWidgets('Login TextField uses rounded focused border (radius 20)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen()));

    final emailFinder = find.byType(TextField).first;
    await tester.tap(emailFinder);
    await tester.pumpAndSettle();

    final tf = tester.widget<TextField>(emailFinder);
    final fb = tf.decoration?.focusedBorder;
    expect(fb, isA<OutlineInputBorder>());
    final obr = fb as OutlineInputBorder;
    expect(obr.borderRadius, BorderRadius.circular(20));
  });

  testWidgets('Register TextField uses rounded focused border (radius 20)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: RegisterScreen()));

    final nameFinder = find.byKey(const Key('register_name'));
    expect(nameFinder, findsOneWidget);

    await tester.tap(nameFinder);
    await tester.pumpAndSettle();

    final tf = tester.widget<TextField>(nameFinder);
    final fb = tf.decoration?.focusedBorder;
    expect(fb, isA<OutlineInputBorder>());
    final obr = fb as OutlineInputBorder;
    expect(obr.borderRadius, BorderRadius.circular(20));
  });
}
