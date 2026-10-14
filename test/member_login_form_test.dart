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

  testWidgets('password reset uses two full pages and verifies code first', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final resetToken = List.filled(64, 'a').join();
    final paths = <String>[];
    final service = UserProfileService(
      api: MemberApi(
        baseUrl: 'https://test.example/api',
        client: MockClient((request) async {
          paths.add(request.url.path);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/forgot-password')) {
            expect(body['email'], 'member@example.com');
            return http.Response(jsonEncode({'message': 'sent'}), 200);
          }
          if (request.url.path.endsWith('/verify-reset-code')) {
            if (body['code'] != '123456') {
              return http.Response.bytes(
                utf8.encode(jsonEncode({'message': '驗證碼錯誤或已失效'})),
                400,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(jsonEncode({'resetToken': resetToken}), 200);
          }
          expect(request.url.path, '/api/auth/reset-password');
          expect(body['resetToken'], resetToken);
          expect(body['password'], 'NewPass123!');
          return http.Response(jsonEncode({'message': 'updated'}), 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MemberLoginForm(service: service)),
      ),
    );

    await tester.tap(find.text('忘記密碼'));
    await tester.pumpAndSettle();
    expect(find.text('步驟 1／2'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('reset-email')),
      'member@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('reset-primary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-code')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('reset-code')), '000000');
    await tester.tap(find.byKey(const ValueKey('reset-primary')));
    await tester.pumpAndSettle();
    expect(find.text('步驟 1／2'), findsOneWidget);
    expect(find.text('驗證碼錯誤或已失效'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('reset-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('reset-primary')));
    await tester.pumpAndSettle();
    expect(find.text('步驟 2／2'), findsOneWidget);
    expect(paths, contains('/api/auth/verify-reset-code'));

    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'NewPass123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password-confirmation')),
      'NewPass123!',
    );
    await tester.tap(find.byKey(const ValueKey('save-new-password')));
    await tester.pumpAndSettle();
    expect(find.text('密碼已更新，請使用新密碼登入'), findsOneWidget);
    expect(paths.last, '/api/auth/reset-password');
    expect(find.byType(AlertDialog), findsNothing);
  });
}
