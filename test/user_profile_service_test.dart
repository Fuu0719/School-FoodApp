import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/models/user_profile.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://test.example/api';
  const tokenKey = 'member_session:$url';
  final saved = {...UserProfile.demo.toJson(), 'id': '1', 'name': '王小明'};
  late UserProfileService service;
  late Future<http.Response> Function(http.Request) handler;
  http.Response response(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    handler = (req) async =>
        response({'user': saved, 'token': 'session-token'});
    service = UserProfileService(
      api: MemberApi(baseUrl: url, client: MockClient((req) => handler(req))),
    );
  });

  test('login stores only token and logout revokes it', () async {
    await service.login(email: 'test@example.com', password: 'test-password');
    expect(service.profile?.name, '王小明');
    expect(
      await const FlutterSecureStorage().read(key: tokenKey),
      'session-token',
    );
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    handler = (req) async {
      expect(req.url.path, '/api/auth/logout');
      expect(req.headers['Authorization'], 'Bearer session-token');
      return response({'message': 'ok'});
    };
    await service.logout();
    expect(service.isLoggedIn, isFalse);
    expect(await const FlutterSecureStorage().read(key: tokenKey), isNull);
  });

  test('startup revalidates token and discards old demo profile', () async {
    SharedPreferences.setMockInitialValues({
      'user_profile': jsonEncode(UserProfile.demo.toJson()),
    });
    await service.initialize();
    expect(service.isLoggedIn, isFalse);
    FlutterSecureStorage.setMockInitialValues({tokenKey: 'restored-token'});
    handler = (req) async {
      expect(req.headers['Authorization'], 'Bearer restored-token');
      return response(saved);
    };
    await service.initialize();
    expect(service.profile?.id, '1');
  });

  test(
    'expired tokens are cleared, network failure does not authenticate',
    () async {
      FlutterSecureStorage.setMockInitialValues({tokenKey: 'expired-token'});
      handler = (_) async => response({'message': 'expired'}, 401);
      await service.initialize();
      expect(service.isLoggedIn, isFalse);
      expect(await const FlutterSecureStorage().read(key: tokenKey), isNull);
      FlutterSecureStorage.setMockInitialValues({tokenKey: 'valid-token'});
      handler = (_) async => throw http.ClientException('offline');
      await service.initialize();
      expect(service.isLoggedIn, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: tokenKey),
        'valid-token',
      );
    },
  );

  test('profile is changed only after successful server save', () async {
    await service.login(email: 'test@example.com', password: 'test-password');
    final changed = service.profile!.copyWith(
      name: '新姓名',
      clearBudgetMax: true,
      dietaryTags: ['高蛋白'],
      healthGoal: HealthGoal.muscleGain,
    );
    handler = (_) async => response({'message': 'invalid'}, 400);
    await expectLater(
      service.updateProfile(changed),
      throwsA(isA<MemberApiException>()),
    );
    expect(service.profile?.name, '王小明');
    handler = (req) async {
      expect(req.method, 'PUT');
      expect(jsonDecode(req.body)['budgetMax'], isNull);
      return response(changed.toJson());
    };
    await service.updateProfile(changed);
    expect(service.profile?.name, '新姓名');
    expect(service.profile?.budgetMax, isNull);
    expect(service.profile?.healthGoal, HealthGoal.muscleGain);
  });

  test(
    'registration authenticates immediately, and rejects duplicate accounts',
    () async {
      handler = (_) async =>
          response({'user': saved, 'token': 'new-token'}, 201);
      await service.register(
        name: '王小明',
        email: 'test@example.com',
        password: 'test-password',
      );
      expect(service.isLoggedIn, isTrue);
      expect(
        await const FlutterSecureStorage().read(key: tokenKey),
        'new-token',
      );
      handler = (_) async => response({'message': '此 Email 已註冊'}, 409);
      await expectLater(
        service.register(
          name: '王小明',
          email: 'test@example.com',
          password: 'test-password',
        ),
        throwsA(isA<MemberApiException>()),
      );
      expect(service.isBusy, isFalse);
    },
  );

  test('logout network failure retains current session for retry', () async {
    await service.login(email: 'test@example.com', password: 'test-password');
    handler = (_) async => throw http.ClientException('offline');
    await expectLater(service.logout(), throwsA(isA<MemberApiException>()));
    expect(service.isLoggedIn, isTrue);
    expect(
      await const FlutterSecureStorage().read(key: tokenKey),
      'session-token',
    );
  });
}
