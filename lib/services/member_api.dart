import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MemberApiException implements Exception {
  const MemberApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class MemberApi {
  MemberApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? const String.fromEnvironment('API_BASE_URL'))
          .replaceFirst(RegExp(r'/+$'), '');
  final http.Client _client;
  final String baseUrl;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
    String? idempotencyKey,
  }) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !['http', 'https'].contains(base.scheme)) {
      throw const MemberApiException('尚未設定會員服務網址');
    }
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await (() async {
        return http.Response.fromStream(await _client.send(request));
      })().timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MemberApiException(
          decoded['message'] is String
              ? decoded['message'] as String
              : '請求失敗，請稍後再試',
          response.statusCode,
        );
      }
      return decoded;
    } on TimeoutException {
      throw const MemberApiException('連線逾時，請檢查網路後再試');
    } on http.ClientException {
      throw const MemberApiException('無法連線會員服務，請檢查網路後再試');
    } on FormatException {
      throw const MemberApiException('會員服務回應異常，請稍後再試');
    }
  }
}
