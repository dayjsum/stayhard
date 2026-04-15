import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayhard/screens/onboarding_screen.dart';

void main() {
  testWidgets('onboarding shows lock-in flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onLocked: () {}),
      ),
    );
    expect(find.text('One-time setup'), findsOneWidget);
    expect(find.text('LOCK IN'), findsOneWidget);
  });
}
