import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/member_login_form.dart';

void main() {
  testWidgets(
    'registration validates confirmation and shows server errors on a small display',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      var calls = 0;
      final service = UserProfileService(
        api: MemberApi(
          baseUrl: 'https://test.example/api',
          client: MockClient((request) async {
            calls++;
            return http.Response(
              jsonEncode({'message': '此 Email 已註冊'}),
              409,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MemberLoginForm(service: service),
            ),
          ),
        ),
      );
      await tester.tap(find.text('建立帳號'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('member-name')), '註冊測試');
      await tester.enterText(
        find.byKey(const ValueKey('member-email')),
        'test@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('member-password')),
        'TestPass123!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('member-confirmation')),
        'wrong-password',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('member-submit')));
      await tester.tap(find.byKey(const ValueKey('member-submit')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('兩次密碼不一致'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('member-confirmation')),
        'TestPass123!',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('member-submit')));
      await tester.tap(find.byKey(const ValueKey('member-submit')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('此 Email 已註冊'), findsOneWidget);
      expect(service.isLoggedIn, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
