import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shankh_alarm/theme.dart';

void main() {
  testWidgets('App theme renders the Shankh Alarm title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('Shankh Alarm')),
      ),
    );

    expect(find.text('Shankh Alarm'), findsOneWidget);
  });
}
