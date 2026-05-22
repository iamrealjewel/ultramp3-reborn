import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultramp3/features/splash/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen rendering smoke test', (WidgetTester tester) async {
    // Build the splash screen within a MaterialApp container.
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Verify that our splash screen text elements are present
    expect(find.text('ULTRAMP3'), findsOneWidget);
    expect(find.text('REBORN'), findsOneWidget);
    expect(find.text('INDEXING STORAGE'), findsOneWidget);
  });
}
