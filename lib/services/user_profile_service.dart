import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/models/user_profile.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/member_activity_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService extends ChangeNotifier {
  UserProfileService({
    MemberApi? api,
    FlutterSecureStorage? storage,
    UserActivityService? activity,
  }) : _api = api ?? MemberApi(),
       _activity = activity ?? UserActivityService.instance,
       _storage = storage ?? const FlutterSecureStorage();

  static final UserProfileService instance = UserProfileService();
  MemberApi _api;
  final UserActivityService _activity;
  FlutterSecureStorage _storage;
  UserProfile? _profile;
  String? _token;
  bool _busy = false;
  bool _testing = false;
  String? errorMessage;
  String get _tokenKey => 'member_session:${_api.baseUrl}';

  UserProfile? get profile => _profile;
  bool get isLoggedIn => _profile != null;
  bool get isBusy => _busy;

  Future<void> initialize() async {
    _profile = null;
    _token = null;
    errorMessage = null;
    try {
      // A cached demo profile cannot authenticate a real member.
      await (await SharedPreferences.getInstance()).remove('user_profile');
      _token = await _storage.read(key: _tokenKey);
      if (_token != null) {
        await _acceptProfile(await _api.request('GET', '/me', token: _token));
      }
    } on MemberApiException catch (error) {
      errorMessage = error.message;
      if (error.statusCode == 401) await _clearSession();
    } on PlatformException {
      errorMessage = '無法讀取登入資料，請重新登入';
    } on MissingPluginException {
      errorMessage = '登入元件尚未就緒，請完整重新啟動 App';
    }
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _perform(() async {
      final response = await _api.request(
        'POST',
        '/auth/register',
        body: {'name': name, 'email': email, 'password': password},
      );
      await _acceptSession(response);
    });
  }

  Future<void> login({required String email, required String password}) {
    return _perform(() async {
      final response = await _api.request(
        'POST',
        '/auth/login',
        body: {'email': email, 'password': password},
      );
      await _acceptSession(response);
    });
  }

  Future<void> _acceptSession(Map<String, dynamic> response) async {
    final token = response['token'];
    if (token is! String ||
        token.isEmpty ||
        response['user'] is! Map<String, dynamic>) {
      throw const MemberApiException('會員服務回應格式不正確');
    }
    await _storage.write(key: _tokenKey, value: token);
    _token = token;
    await _acceptProfile(response['user'] as Map<String, dynamic>);
    if (_profile == null) {
      throw const MemberApiException('登入已失效，請重新登入', 401);
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    if (_testing) {
      _profile = profile;
      notifyListeners();
      return;
    }
    await _perform(() async {
      if (_token == null) throw const MemberApiException('請先登入', 401);
      final saved = await _api.request(
        'PUT',
        '/me',
        token: _token,
        body: profile.toJson(),
      );
      await _acceptProfile(saved);
    });
  }

  Future<void> logout() async {
    if (_testing) {
      _profile = null;
      notifyListeners();
      return;
    }
    await _perform(() async {
      if (_token != null) {
        try {
          await _api.request('POST', '/auth/logout', token: _token);
        } on MemberApiException catch (error) {
          if (error.statusCode != 401) rethrow;
        }
      }
      await _clearSession();
    });
  }

  Future<void> _acceptProfile(Map<String, dynamic> json) async {
    final UserProfile profile;
    try {
      profile = UserProfile.fromJson(json);
    } on TypeError {
      throw const MemberApiException('會員資料格式不正確');
    }
    if (profile.id == null) throw const MemberApiException('會員資料格式不正確');
    final token = _token;
    _profile = profile;
    await _activity.switchAccount(
      '${_api.baseUrl}:${profile.id}',
      cloudApi: token == null
          ? null
          : MemberActivityApi(
              api: _api,
              token: token,
              onUnauthorized: () async {
                if (_token == token) {
                  await _clearSession();
                  errorMessage = '登入已失效，請重新登入';
                  notifyListeners();
                }
              },
            ),
    );
  }

  Future<void> _clearSession() async {
    _token = null;
    _profile = null;
    await _activity.switchAccount(null);
    await _storage.delete(key: _tokenKey);
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) throw const MemberApiException('請等待目前操作完成');
    _busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } on MemberApiException catch (error) {
      errorMessage = error.message;
      if (error.statusCode == 401 && _token != null) await _clearSession();
      rethrow;
    } on PlatformException {
      errorMessage = '無法存取安全登入資料，請重新啟動 App';
      throw MemberApiException(errorMessage!);
    } on MissingPluginException {
      errorMessage = '登入元件尚未就緒，請停止 App 後重新執行';
      throw MemberApiException(errorMessage!);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void loginWithDemo() {
    assert(() {
      _testing = true;
      return true;
    }());
    if (!_testing) throw StateError('Test fixture only');
    _profile = UserProfile.demo;
    notifyListeners();
  }

  @visibleForTesting
  void configureForTesting(MemberApi api, FlutterSecureStorage storage) {
    _api = api;
    _storage = storage;
  }

  @visibleForTesting
  void clearForTesting() {
    _profile = null;
    _token = null;
    _testing = false;
    _busy = false;
    errorMessage = null;
    notifyListeners();
  }
}
