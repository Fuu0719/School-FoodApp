import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/brand_splash_screen.dart';

void main() {
  testWidgets('brand splash waits for initialization and minimum duration', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: BrandLaunchGate(
          initialization: initialization.future,
          child: const Text('app ready'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('brand-splash')), findsOneWidget);
    expect(find.text('app ready'), findsNothing);

    initialization.complete();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('brand-splash')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('app ready'), findsOneWidget);
  });
}
