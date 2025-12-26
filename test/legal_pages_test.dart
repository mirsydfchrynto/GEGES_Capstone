import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/legal/terms_page.dart';
import 'package:geges_smartbarber/screens/legal/privacy_page.dart';

void main() {
  testWidgets('TermsPage shows terms text and has appbar', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const TermsPage()));

    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.textContaining('GEGES SmartBarber - Terms of Service'), findsOneWidget);
  });

  testWidgets('PrivacyPage shows privacy text and has appbar', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const PrivacyPage()));

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.textContaining('GEGES SmartBarber - Privacy Policy'), findsOneWidget);
  });
}
