import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/merchant_account.dart';
import 'package:my_app/models/merchant_product.dart';
import 'package:my_app/models/merchant_registration.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/request_id.dart';

class MerchantAuthService extends ChangeNotifier {
  MerchantAuthService({
    MemberApi? api,
    FlutterSecureStorage? storage,
    bool? useCloud,
  }) : _api = api ?? MemberApi(),
       _storage = storage ?? const FlutterSecureStorage(),
       useCloud = useCloud ?? FoodCatalogRepository.instance.useCloud;
  static final MerchantAuthService instance = MerchantAuthService();
  final MemberApi _api;
  final FlutterSecureStorage _storage;
  final bool useCloud;
  MerchantAccount? _account;
  String? _token;
  bool _busy = false;
  String? errorMessage;
  String? _cursor;
  bool loaded = false;
  final List<MerchantProduct> _products = [];
  MerchantProductInput? _pendingInput;
  String? _pendingId;
  bool pendingCorrupt = false;
  MerchantAccount? get account => _account;
  bool get isLoggedIn => _account != null;
  bool get isBusy => _busy;
  List<MerchantProduct> get products => List.unmodifiable(_products);
  bool get hasMore => _cursor != null;
  bool get hasPendingDraft => _pendingId != null;
  MerchantProductInput? get pendingInput => _pendingInput;
  String get _tokenKey => 'merchant_session:${_api.baseUrl}';
  String get _pendingKey => 'merchant_pending:${_api.baseUrl}:${_account!.id}';

  void loginWithDemo({String? email}) {
    if (useCloud) throw const MemberApiException('雲端模式不可使用展示商家登入');
    _account = MerchantAccount.demo.copyWith(
      email: email?.trim().isNotEmpty == true ? email!.trim() : null,
    );
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() work) async {
    if (_busy) throw const MemberApiException('請等待目前操作完成');
    _busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await work();
    } on MemberApiException catch (error) {
      errorMessage = error.message;
      if (error.statusCode == 401) {
        try {
          await _clearSession();
        } catch (_) {
          throw const MemberApiException('商家登入已失效，安全儲存清理失敗，請重新啟動 App');
        }
      }
      rethrow;
    } catch (_) {
      errorMessage = '商家服務或本機儲存未完成，請重新確認';
      throw MemberApiException(errorMessage!);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    if (!useCloud || isLoggedIn) return;
    await _run(() async {
      _token = await _storage.read(key: _tokenKey);
      if (_token == null) return;
      _account = MerchantAccount.fromJson(
        await _api.request('GET', '/merchant/me', token: _token),
      );
      await _restorePending();
    });
  }

  Future<void> register(MerchantRegistration registration) => _run(() async {
    if (isLoggedIn) throw const MemberApiException('請先登出目前商家');
    await _api.request(
      'POST',
      '/merchant/auth/register',
      body: registration.toJson(),
    );
  });

  Future<void> login(String email, String password) async {
    await _run(() async {
      if (isLoggedIn) throw const MemberApiException('請先登出目前商家');
      final data = await _api.request(
        'POST',
        '/merchant/auth/login',
        body: {'email': email, 'password': password},
      );
      final token = data['token'];
      if (token is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
        throw const MemberApiException('商家登入回應異常');
      }
      final account = MerchantAccount.fromJson(
        data['merchant'] as Map<String, dynamic>,
      );
      await _storage.write(key: _tokenKey, value: token);
      _token = token;
      _account = account;
      await _restorePending();
    });
  }

  Future<void> logout() async {
    if (!useCloud) {
      _account = null;
      notifyListeners();
      return;
    }
    await _run(() async {
      if (_token != null) {
        try {
          await _api.request('POST', '/merchant/auth/logout', token: _token);
        } on MemberApiException catch (error) {
          if (error.statusCode != 401) rethrow;
        }
      }
      await _clearSession();
    });
  }

  Future<void> _clearSession() async {
    _account = null;
    _token = null;
    _products.clear();
    _cursor = null;
    loaded = false;
    _pendingId = null;
    _pendingInput = null;
    pendingCorrupt = false;
    await _storage.delete(key: _tokenKey);
  }

  Future<void> _restorePending() async {
    _pendingId = null;
    _pendingInput = null;
    pendingCorrupt = false;
    try {
      final encoded = (await SharedPreferences.getInstance()).getString(
        _pendingKey,
      );
      if (encoded == null) return;
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      final id = data['id'] as String;
      if (!RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(id)) {
        throw const FormatException();
      }
      _pendingInput = MerchantProductInput.fromJson(
        data['input'] as Map<String, dynamic>,
      );
      _pendingId = id;
    } catch (_) {
      pendingCorrupt = true;
    }
  }

  void _requireAccount() {
    if (_token == null || _account == null) {
      throw const MemberApiException('請先登入商家帳號', 401);
    }
  }

  Future<void> refresh({bool more = false}) => _run(() async {
    _requireAccount();
    if (more && _cursor == null) return;
    final data = await _api.request(
      'GET',
      more ? '/merchant/products?before=$_cursor' : '/merchant/products',
      token: _token,
    );
    final products = (data['items'] as List)
        .map((row) => MerchantProduct.fromJson(row as Map<String, dynamic>))
        .toList();
    final cursor = data['nextCursor'] as String?;
    if (cursor != null &&
        (!RegExp(r'^[1-9][0-9]*$').hasMatch(cursor) ||
            (more && cursor == _cursor))) {
      throw const MemberApiException('商品分頁回應異常');
    }
    if (!more) _products.clear();
    final ids = _products.map((p) => p.id).toSet();
    _products.addAll(products.where((p) => ids.add(p.id)));
    _cursor = cursor;
    loaded = true;
  });
  Future<MerchantProduct> detail(String id) => _run(() async {
    _requireAccount();
    return MerchantProduct.fromJson(
      await _api.request('GET', '/merchant/products/$id', token: _token),
    );
  });
  void _replace(MerchantProduct product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) {
      _products.insert(0, product);
    } else {
      _products[index] = product;
    }
  }

  Future<MerchantProduct> save(
    MerchantProductInput input, {
    MerchantProduct? existing,
  }) => _run(() async {
    _requireAccount();
    if (pendingCorrupt) throw const MemberApiException('待確認草稿資料異常，請聯絡管理者');
    if (existing != null) {
      final saved = MerchantProduct.fromJson(
        await _api.request(
          'PUT',
          '/merchant/products/${existing.id}',
          token: _token,
          body: {...input.toJson(), 'revision': existing.revision},
        ),
      );
      _replace(saved);
      return saved;
    }
    final preferences = await SharedPreferences.getInstance();
    _pendingInput ??= input;
    _pendingId ??= newRequestId();
    final key = _pendingKey;
    if (!await preferences.setString(
      key,
      jsonEncode({'id': _pendingId, 'input': _pendingInput!.toJson()}),
    )) {
      throw const MemberApiException('無法保存草稿識別碼，尚未送出');
    }
    final Map<String, dynamic> result;
    try {
      result = await _api.request(
        'POST',
        '/merchant/products',
        token: _token,
        idempotencyKey: _pendingId,
        body: _pendingInput!.toJson(),
      );
    } on MemberApiException catch (error) {
      if ([400, 404].contains(error.statusCode) &&
          await preferences.remove(key)) {
        _pendingId = null;
        _pendingInput = null;
      }
      rethrow;
    }
    final saved = MerchantProduct.fromJson(
      result['product'] as Map<String, dynamic>,
    );
    if (!await preferences.remove(key)) {
      throw const MemberApiException('草稿已建立，本機確認未完成，請用原草稿重試');
    }
    _pendingId = null;
    _pendingInput = null;
    _replace(saved);
    return saved;
  });
  Future<void> setStatus(MerchantProduct product, String status) =>
      _run(() async {
        _requireAccount();
        final saved = MerchantProduct.fromJson(
          await _api.request(
            'PUT',
            '/merchant/products/${product.id}/status',
            token: _token,
            body: {'revision': product.revision, 'status': status},
          ),
        );
        _replace(saved);
      });
  @visibleForTesting
  void clearForTesting() {
    _account = null;
    _token = null;
    _busy = false;
    _products.clear();
    _pendingId = null;
    _pendingInput = null;
    pendingCorrupt = false;
    loaded = false;
    _cursor = null;
    errorMessage = null;
    notifyListeners();
  }
}
