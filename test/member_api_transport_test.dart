import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/services/member_api.dart';

void main() {
  test('API transport permits HTTPS and local debug HTTP only', () async {
    final client = MockClient((request) async => http.Response('{}', 200));

    await MemberApi(
      baseUrl: 'https://api.example.test',
      client: client,
    ).request('GET', '/health');
    await MemberApi(
      baseUrl: 'http://127.0.0.1:3000',
      client: client,
    ).request('GET', '/health');

    await expectLater(
      MemberApi(
        baseUrl: 'http://api.example.test',
        client: client,
      ).request('GET', '/health'),
      throwsA(isA<MemberApiException>()),
    );
  });
}
