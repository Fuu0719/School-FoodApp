import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/user_profile.dart';
import 'package:my_app/screens/profile_screen.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_profile_service.dart';

void main() {
  test('missing measurements never fall back to demo values', () {
    final profile = UserProfile.fromJson({
      ...UserProfile.demo.toJson(),
      'heightCm': null,
      'weightKg': null,
    });
    expect(profile.heightCm, isNull);
    expect(profile.weightKg, isNull);
    expect(profile.needsProfileCompletion, isTrue);
    expect(profile.bmiLabel, '未填寫');
    expect(
      profile.copyWith(heightCm: 160, weightKg: 50).needsProfileCompletion,
      isFalse,
    );
  });
  testWidgets(
    'new member automatically opens edit form with blank measurements',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final service = UserProfileService.instance;
      service.configureForTesting(
        MemberApi(
          baseUrl: 'https://example.test/api',
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'token': 'new-session',
                'user': {
                  ...UserProfile.demo.toJson(),
                  'id': 'new',
                  'heightCm': null,
                  'weightKg': null,
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
        const FlutterSecureStorage(),
      );
      await service.login(email: 'new@example.test', password: 'test-password');
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.text('編輯會員資料'), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(
        fields
            .firstWhere((field) => field.decoration?.labelText == '身高（公分）')
            .controller!
            .text,
        '',
      );
      expect(
        fields
            .firstWhere((field) => field.decoration?.labelText == '體重（公斤）')
            .controller!
            .text,
        '',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
