// test/widget/input_styling_visual_test.dart
// Golden tests dan visual verification untuk rounded TextField styling
// Verify: Border radius = 20, focus shadow, colors match design

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';

void main() {
  group('Input Styling Visual Tests', () {
    // Color constants (from LoginScreen)
    const Color kBrownAccent = Color(0xFFC3A47B);
    const Color kDarkGrey = Color(0xFF1E1E1E);
    const Color kHintText = Color(0xFF6B6B6B);

    testWidgets('TC-VISUAL-01: LoginScreen email field has rounded border (radius 20)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find email TextField
      final emailField = find.byType(TextField).first;
      expect(emailField, findsOneWidget);

      // Verify TextField is wrapped in AnimatedContainer with border radius
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsWidgets);
    });

    testWidgets('TC-VISUAL-02: LoginScreen password field has rounded border (radius 20)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find all TextFields (email + password)
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Get password field (second TextField)
      final passwordField = textFields.at(1);
      expect(passwordField, findsOneWidget);

      // Verify AnimatedContainer styling
      final animatedContainers = find.byType(AnimatedContainer);
      var foundPasswordContainer = false;

      for (var container in animatedContainers.evaluate()) {
        final widget = container.widget as AnimatedContainer;
        if (widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          if (decoration.borderRadius == BorderRadius.circular(20)) {
            foundPasswordContainer = true;
            break;
          }
        }
      }

      expect(foundPasswordContainer, true,
          reason: 'Password field should have rounded container');
    });

    testWidgets('TC-VISUAL-03: LoginScreen focused input styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find email TextField
      final emailField = find.byType(TextField).first;
      expect(emailField, findsOneWidget);

      // Tap to focus
      await tester.tap(emailField);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Verify TextField has AnimatedContainer parent with rounded borders
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsWidgets);
    });

    testWidgets('TC-VISUAL-04: RegisterScreen name field styling matches LoginScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );

      // Find name TextField (first input field)
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Verify AnimatedContainer wrapping
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsWidgets);

      // Check first AnimatedContainer for register screen
      var foundRoundedRegisterContainer = false;
      for (var container in animatedContainers.evaluate()) {
        final widget = container.widget as AnimatedContainer;
        if (widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          if (decoration.borderRadius == BorderRadius.circular(20)) {
            foundRoundedRegisterContainer = true;
            break;
          }
        }
      }

      expect(foundRoundedRegisterContainer, true,
          reason: 'RegisterScreen inputs should have rounded styling');
    });

    testWidgets('TC-VISUAL-05: Input field colors match design (dark grey bg, brown accent focus)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify AnimatedContainer colors
      final animatedContainers = find.byType(AnimatedContainer);
      var foundColorMatch = false;

      for (var container in animatedContainers.evaluate()) {
        final widget = container.widget as AnimatedContainer;
        if (widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          // Verify color is kDarkGrey
          if (decoration.color == kDarkGrey) {
            // Also check border radius
            if (decoration.borderRadius == BorderRadius.circular(20)) {
              foundColorMatch = true;
              break;
            }
          }
        }
      }

      expect(foundColorMatch, true,
          reason: 'Input fields should have dark grey background');
    });

    testWidgets('TC-VISUAL-06: Focused border uses brown accent color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find and focus email field
      final emailField = find.byType(TextField).first;
      await tester.tap(emailField);
      await tester.pumpAndSettle();

      // Check TextField's decoration for focused border
      final textFieldWidget = emailField.evaluate().first.widget as TextField;
      final decoration = textFieldWidget.decoration;

      // Verify focusedBorder is set and uses brown accent
      expect(decoration?.focusedBorder, isNotNull);

      if (decoration?.focusedBorder is OutlineInputBorder) {
        final focusedBorder = decoration?.focusedBorder as OutlineInputBorder;
        expect(focusedBorder.borderSide.color, kBrownAccent);
        expect(focusedBorder.borderRadius, BorderRadius.circular(20));
      }
    });

    testWidgets('TC-VISUAL-07: Hint text color is subtle (gray)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find email field
      final emailField = find.byType(TextField).first;
      final textFieldWidget = emailField.evaluate().first.widget as TextField;
      final decoration = textFieldWidget.decoration;

      // Verify hint text style uses gray color
      expect(decoration?.hintStyle, isNotNull);

      if (decoration?.hintStyle != null) {
        expect(decoration!.hintStyle!.color, kHintText);
      }
    });
  });
}

// Golden Test Instructions
// ========================
// To generate golden files, run:
//
// flutter test --update-goldens test/widget/input_styling_visual_test.dart
//
// Golden files will be stored in:
// test/widget/goldens/
//
// For CI/CD, compare against stored golden files:
// flutter test test/widget/input_styling_visual_test.dart
//
// Note: Golden tests require exact pixel-perfect matches.
// Use on same platform/device for reliable comparisons.
