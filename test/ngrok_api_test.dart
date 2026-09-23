import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/services/member_api.dart';

void main() {
  for (final host in [
    'demo.ngrok-free.dev',
    'demo.ngrok-free.app',
    'example.com',
    'ngrok-free.dev.example.com',
  ]) {
    test('ngrok header is scoped to $host', () async {
      final api = MemberApi(
        baseUrl: 'https://$host/api',
        client: MockClient((request) async {
          expect(
            request.headers['ngrok-skip-browser-warning'],
            host == 'demo.ngrok-free.dev' || host == 'demo.ngrok-free.app'
                ? 'true'
                : isNull,
          );
          return http.Response('{"status":"ok"}', 200);
        }),
      );
      expect(await api.request('GET', '/health'), {'status': 'ok'});
    });
  }
}
