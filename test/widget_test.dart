import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elderly_care_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ElderlyCarApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
