// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voices_app/main.dart';

void main() {
  testWidgets('App renders home title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VoicesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('实时语音转写'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });
}
