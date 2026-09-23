import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/cart_item.dart';
import 'package:my_app/models/food_feedback.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/models/purchase_record.dart';
import 'package:my_app/models/search_log.dart';
import 'package:my_app/models/pending_checkout.dart';
import 'package:my_app/services/member_activity_api.dart';
import 'package:my_app/services/member_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserActivityService extends ChangeNotifier {
  UserActivityService({FoodCatalogRepository? catalog})
    : _catalog = catalog ?? FoodCatalogRepository.instance;

  static final UserActivityService instance = UserActivityService();
  final FoodCatalogRepository _catalog;
  bool get isCloud => _catalog.useCloud;
  MemberActivityApi? _cloudApi;
  int _generation = 0;
  bool _busy = false;
  Future<void> _operationDone = Future.value();
  bool get isSyncing => isCloud && _busy;
  bool cloudLoaded = false;
  bool get cartLocked =>
      isCloud && (_busy || hasPendingCheckout || _pendingCorrupt);
  PendingCheckout? _pendingCheckout;
  bool _pendingCorrupt = false;
  bool get checkoutNeedsReview => _pendingCorrupt;
  bool get hasPendingCheckout => _pendingCheckout != null;
  int get checkoutQuantity =>
      _pendingCheckout?.items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      ) ??
      cartTotalQuantity;
  String? _ordersCursor;
  bool get hasMoreOrders => _ordersCursor != null;
  String? errorMessage;
  int errorRevision = 0;
  bool isFavoriteBusy(String id) => isCloud && _busy;
  String? _accountId;
  String get _prefix =>
      '${isCloud ? 'cloud:' : ''}${_accountId == null ? 'guest:' : 'member:$_accountId:'}';
  String get _pendingKey => '${_prefix}pending_checkout';
  String get _favoriteIdsKey => '${_prefix}favorite_food_ids';
  String get _historyIdsKey => '${_prefix}history_food_ids';
  String get _searchLogsKey => '${_prefix}search_logs';
  String get _cartItemsKey => '${_prefix}cart_items';
  String get _purchaseRecordsKey => '${_prefix}purchase_records';
  String get _foodFeedbackKey => '${_prefix}food_feedback';

  Future<void> switchAccount(
    String? accountId, {
    MemberActivityApi? cloudApi,
  }) async {
    if (_accountId == accountId && _cloudApi?.token == cloudApi?.token) return;
    _generation++;
    _busy = false;
    _cloudApi = cloudApi;
    _pendingCheckout = null;
    _pendingCorrupt = false;
    _ordersCursor = null;
    cloudLoaded = false;
    errorMessage = null;
    _accountId = accountId;
    _favorites.clear();
    _history.clear();
    _searchLogs.clear();
    _cartQuantities.clear();
    _purchaseRecords.clear();
    _foodFeedback.clear();
    await initialize();
    notifyListeners();
  }

  SharedPreferences? _preferences;
  final Map<String, FoodItem> _favorites = {};
  final List<FoodItem> _history = [];
  final List<SearchLog> _searchLogs = [];
  final Map<String, int> _cartQuantities = {};
  final List<PurchaseRecord> _purchaseRecords = [];
  final Map<String, FoodFeedback> _foodFeedback = {};
  final List<EcoRanking> _ecoLeaderboard = [];
  List<EcoRanking> get ecoLeaderboard => List.unmodifiable(_ecoLeaderboard);

  List<FoodItem> get favorites => List.unmodifiable(_favorites.values);

  List<FoodItem> get history => List.unmodifiable(_history);

  List<SearchLog> get searchLogs => List.unmodifiable(_searchLogs);

  List<CartItem> get cartItems {
    final items = <CartItem>[];

    for (final entry in _cartQuantities.entries) {
      final food = _findFood(entry.key);
      if (food != null && entry.value > 0) {
        items.add(CartItem(food: food, quantity: entry.value));
      }
    }

    return List.unmodifiable(items);
  }

  List<PurchaseRecord> get purchaseRecords {
    return List.unmodifiable(_purchaseRecords);
  }

  List<FoodFeedback> get feedbacks {
    return List.unmodifiable(_foodFeedback.values);
  }

  int get cartTotalQuantity {
    return cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  int get cartTotalPrice {
    return cartItems.fold(0, (sum, item) => sum + item.subtotal);
  }

  int get ecoPoints {
    return purchaseRecords.fold(
      0,
      (sum, record) =>
          sum +
          (record.cloudEcoPoints ??
              record.items.fold(
                0,
                (itemSum, item) => itemSum + _ecoPointsForCartItem(item),
              )),
    );
  }

  int get savedFoodCount {
    return purchaseRecords.fold(
      0,
      (sum, record) =>
          sum +
          record.items
              .where((item) => item.food.isExpiringSoon)
              .fold(0, (itemSum, item) => itemSum + item.quantity),
    );
  }

  int get savedAmount {
    return purchaseRecords.fold(
      0,
      (sum, record) =>
          sum +
          (record.cloudSavedAmount ??
              record.items.fold(0, (itemSum, item) {
                final originalPrice = item.food.originalPrice;
                if (!item.food.isExpiringSoon || originalPrice == null) {
                  return itemSum;
                }

                return itemSum +
                    (originalPrice - item.food.price) * item.quantity;
              })),
    );
  }

  bool isFavorite(String foodId) {
    return _favorites.containsKey(foodId);
  }

  bool isInCart(String foodId) {
    return (_cartQuantities[foodId] ?? 0) > 0;
  }

  int cartQuantity(String foodId) {
    return _cartQuantities[foodId] ?? 0;
  }

  FoodFeedback? feedbackFor(String foodId) {
    return _foodFeedback[foodId];
  }

  Future<void> initialize() async {
    final generation = _generation;
    try {
      _preferences = await SharedPreferences.getInstance();
    } on MissingPluginException {
      _preferences = null;
      return;
    }

    if (generation != _generation) return;
    if (!isCloud) {
      _restoreFavorites();
      _restoreHistory();
      _restorePurchaseRecords();
    }
    _restoreSearchLogs();
    _restoreCartItems();
    _restoreFoodFeedback();
    if (isCloud) {
      _restorePendingCheckout();
      if (_cloudApi != null && _catalog.isLoaded) await refreshCloud();
      if (generation == _generation && _pendingCorrupt) {
        _reportError('待確認訂單資料異常，請勿重複下單，請聯絡管理者確認');
      }
    }
  }

  Future<bool> toggleFavorite(FoodItem food) async {
    if (isCloud) {
      final enabled = !isFavorite(food.id);
      return await _cloudOperation<bool>(
            (api) async {
              await api.favorite(food.id, enabled);
              return true;
            },
            (_) {
              if (enabled) {
                _favorites[food.id] = food.copyWith(isFavorite: true);
              } else {
                _favorites.remove(food.id);
              }
            },
          ) ??
          false;
    }
    if (isFavorite(food.id)) {
      _favorites.remove(food.id);
    } else {
      _favorites[food.id] = food.copyWith(isFavorite: true);
    }

    _persistFavorites();
    notifyListeners();
    return true;
  }

  Future<void> addHistory(FoodItem food) async {
    if (isCloud) {
      final generation = _generation;
      while (_busy) {
        await _operationDone;
        if (generation != _generation) return;
      }
      await _cloudOperation<bool>((api) async {
        await api.view(food.id);
        return true;
      }, (_) => _recordHistory(food));
      return;
    }
    _recordHistory(food);
    _persistHistory();
    notifyListeners();
  }

  void _recordHistory(FoodItem food) {
    _history.removeWhere((item) => item.id == food.id);
    _history.insert(0, food);

    if (_history.length > 20) {
      _history.removeRange(20, _history.length);
    }
  }

  void addSearchLog({required String keyword, required String filterSummary}) {
    final normalizedKeyword = keyword.trim();
    final normalizedSummary = filterSummary.trim();

    if (normalizedKeyword.isEmpty && normalizedSummary.isEmpty) {
      return;
    }

    _searchLogs.removeWhere(
      (log) =>
          log.keyword == normalizedKeyword &&
          log.filterSummary == normalizedSummary,
    );
    _searchLogs.insert(
      0,
      SearchLog(
        keyword: normalizedKeyword,
        filterSummary: normalizedSummary,
        searchedAt: DateTime.now(),
      ),
    );

    if (_searchLogs.length > 10) {
      _searchLogs.removeRange(10, _searchLogs.length);
    }

    _persistSearchLogs();
    notifyListeners();
  }

  void clearSearchLogs() {
    _searchLogs.clear();
    _persistSearchLogs();
    notifyListeners();
  }

  void addToCart(FoodItem food) {
    setCartQuantity(food, cartQuantity(food.id) + 1);
  }

  void increaseCartItem(FoodItem food) {
    addToCart(food);
  }

  void decreaseCartItem(FoodItem food) {
    setCartQuantity(food, cartQuantity(food.id) - 1);
  }

  void setCartQuantity(FoodItem food, int quantity) {
    if (cartLocked) return;
    final nextQuantity = quantity.clamp(0, food.stockCount).toInt();

    if (nextQuantity == 0) {
      _cartQuantities.remove(food.id);
    } else {
      _cartQuantities[food.id] = nextQuantity;
    }

    _persistCartItems();
    notifyListeners();
  }

  bool get canCheckout =>
      !isCloud || (_cloudApi != null && !_busy && !_pendingCorrupt);

  PurchaseRecord? checkoutCart() {
    if (isCloud) return null;
    final items = cartItems;

    if (items.isEmpty) {
      return null;
    }

    final record = PurchaseRecord(
      id: 'purchase-${DateTime.now().microsecondsSinceEpoch}',
      purchasedAt: DateTime.now(),
      items: items,
    );

    _purchaseRecords.insert(0, record);
    if (_purchaseRecords.length > 20) {
      _purchaseRecords.removeRange(20, _purchaseRecords.length);
    }

    _cartQuantities.clear();
    _persistCartItems();
    _persistPurchaseRecords();
    notifyListeners();
    return record;
  }

  Future<T?> _cloudOperation<T>(
    Future<T> Function(MemberActivityApi) operation,
    void Function(T) apply,
  ) async {
    final api = _cloudApi;
    if (api == null) {
      _reportError('請先登入');
      return null;
    }
    if (_busy) {
      _reportError('請等待目前同步完成');
      return null;
    }
    final generation = _generation;
    final completed = Completer<void>();
    _operationDone = completed.future;
    _busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await operation(api);
      if (generation != _generation) return null;
      apply(result);
      return result;
    } on MemberApiException catch (error) {
      if (generation == _generation) {
        _reportError(error.message);
        if (error.statusCode == 401) {
          try {
            await api.onUnauthorized?.call();
          } catch (_) {
            if (generation == _generation) _reportError('登入已失效，請重新登入');
          }
        }
      }
      return null;
    } catch (_) {
      if (generation == _generation) _reportError('同步未完成，請檢查連線後重試');
      return null;
    } finally {
      completed.complete();
      if (generation == _generation) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void _reportError(String message) {
    errorMessage = message;
    errorRevision++;
    notifyListeners();
  }

  Future<bool> refreshCloud() async {
    if (!isCloud || _cloudApi == null || _busy) return false;
    final knownFoods = <String, FoodItem>{
      for (final food in _catalog.allFoods) food.id: food,
      ..._favorites,
      for (final food in _history) food.id: food,
      for (final order in _purchaseRecords)
        for (final item in order.items) item.food.id: item.food,
    };
    FoodItem? resolve(String id) => _findFood(id) ?? knownFoods[id];
    final snapshot = await _cloudOperation(
      (api) async {
        final favorites = await api.favorites();
        final history = await api.history();
        final orders = await api.orders();
        final leaderboard = await api.leaderboard();
        return (
          favorites: favorites,
          history: history,
          orders: orders,
          leaderboard: leaderboard,
        );
      },
      (data) {
        _favorites
          ..clear()
          ..addEntries(
            data.favorites
                .map(resolve)
                .whereType<FoodItem>()
                .map(
                  (food) => MapEntry(food.id, food.copyWith(isFavorite: true)),
                ),
          );
        _history
          ..clear()
          ..addAll(data.history.map(resolve).whereType<FoodItem>());
        _purchaseRecords
          ..clear()
          ..addAll(data.orders.records);
        _ordersCursor = data.orders.nextCursor;
        _ecoLeaderboard
          ..clear()
          ..addAll(data.leaderboard);
        cloudLoaded = true;
      },
    );
    return snapshot != null;
  }

  void applyCheckoutStock(PurchaseRecord record) {
    for (final line in record.items) {
      void update(FoodItem food) {
        final remaining = (food.stockCount - line.quantity)
            .clamp(0, food.stockCount)
            .toInt();
        final updated = food.copyWith(stockCount: remaining);
        if (_favorites.containsKey(food.id)) _favorites[food.id] = updated;
        final index = _history.indexWhere((item) => item.id == food.id);
        if (index >= 0) _history[index] = updated;
      }

      FoodItem? known = _favorites[line.food.id];
      if (known == null) {
        for (final food in _history) {
          if (food.id == line.food.id) {
            known = food;
            break;
          }
        }
      }
      if (known != null) update(known);
    }
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    final cursor = _ordersCursor;
    if (cursor == null || _busy) return;
    await _cloudOperation((api) => api.orders(before: cursor), (page) {
      if (page.nextCursor == cursor) throw const MemberApiException('訂單分頁回應異常');
      final ids = _purchaseRecords.map((record) => record.id).toSet();
      _purchaseRecords.addAll(
        page.records.where((record) => ids.add(record.id)),
      );
      _ordersCursor = page.nextCursor;
    });
  }

  Future<void> clearHistory() async {
    if (!isCloud) {
      _history.clear();
      _persistHistory();
      notifyListeners();
      return;
    }
    await _cloudOperation((api) async {
      await api.clearHistory();
      return true;
    }, (_) => _history.clear());
  }

  void _restorePendingCheckout() {
    try {
      final encoded = _preferences?.getString(_pendingKey);
      if (encoded == null) {
        _pendingCheckout = null;
        _pendingCorrupt = false;
        return;
      }
      _pendingCheckout = PendingCheckout.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      _pendingCorrupt = false;
    } catch (_) {
      _pendingCorrupt = true;
      _reportError('待確認訂單資料異常，請勿重複下單，請聯絡管理者確認');
    }
  }

  Future<PurchaseRecord?> submitCart() async {
    if (!isCloud) return checkoutCart();
    if (!canCheckout) return null;
    if (_pendingCheckout == null && cartItems.isEmpty) return null;
    if (_pendingCheckout == null &&
        (cartItems.length > 50 ||
            cartItems.any((item) => item.quantity > 99))) {
      _reportError('每張訂單最多 50 種餐點，每種最多 99 份');
      return null;
    }
    final generation = _generation;
    final pendingKey = _pendingKey;
    final cartKey = _cartItemsKey;
    return _cloudOperation(
      (api) async {
        final preferences = _preferences;
        if (preferences == null) {
          throw const MemberApiException('無法保存訂單識別碼，請重新啟動 App 後再試');
        }
        final pending =
            _pendingCheckout ??
            PendingCheckout.create(
              cartItems
                  .map((item) => PendingCartLine(item.food.id, item.quantity))
                  .toList(),
            );
        _pendingCheckout = pending;
        if (!await preferences.setString(
          pendingKey,
          jsonEncode(pending.toJson()),
        )) {
          throw const MemberApiException('無法保存訂單識別碼，尚未送出訂單');
        }
        if (generation != _generation) {
          throw const MemberApiException('帳號已切換，未送出訂單');
        }
        final PurchaseRecord record;
        try {
          record = await api.checkout(
            pending.id,
            pending.items.map((item) => item.toJson()).toList(),
          );
        } on MemberApiException catch (error) {
          // A definite validation/stock rejection can be edited. Ambiguous responses keep the key.
          if ((error.statusCode == 400 || error.statusCode == 409) &&
              !error.message.contains('識別碼')) {
            if (await preferences.remove(pendingKey) &&
                generation == _generation) {
              _pendingCheckout = null;
            }
          }
          rethrow;
        }
        // Clear the persisted cart first. A crash here can safely replay the still-pending request.
        if (!await preferences.remove(cartKey) ||
            !await preferences.remove(pendingKey)) {
          throw const MemberApiException('訂單已建立，本機確認未完成，請用原訂單重試確認');
        }
        return record;
      },
      (record) {
        _pendingCheckout = null;
        _cartQuantities.clear();
        _purchaseRecords.removeWhere((existing) => existing.id == record.id);
        _purchaseRecords.insert(0, record);
      },
    );
  }

  void saveFoodFeedback({
    required FoodItem food,
    required int rating,
    required List<String> tags,
  }) {
    _foodFeedback[food.id] = FoodFeedback(
      foodId: food.id,
      rating: rating.clamp(1, 5).toInt(),
      tags: List.unmodifiable(tags.toSet()),
      createdAt: DateTime.now(),
    );

    _persistFoodFeedback();
    notifyListeners();
  }

  void _restoreFavorites() {
    final favoriteIds = _preferences?.getStringList(_favoriteIdsKey) ?? [];

    _favorites
      ..clear()
      ..addEntries(
        favoriteIds
            .map(_findFood)
            .whereType<FoodItem>()
            .map((food) => MapEntry(food.id, food.copyWith(isFavorite: true))),
      );
  }

  void _restoreHistory() {
    final historyIds = _preferences?.getStringList(_historyIdsKey) ?? [];

    _history
      ..clear()
      ..addAll(historyIds.map(_findFood).whereType<FoodItem>());
  }

  void _restoreSearchLogs() {
    final encodedLogs = _preferences?.getStringList(_searchLogsKey) ?? [];

    _searchLogs
      ..clear()
      ..addAll(
        encodedLogs
            .map(jsonDecode)
            .whereType<Map<String, Object?>>()
            .map(SearchLog.fromJson),
      );
  }

  void _restoreCartItems() {
    final encodedItems = _preferences?.getStringList(_cartItemsKey) ?? [];

    _cartQuantities.clear();
    for (final encodedItem in encodedItems) {
      final parts = encodedItem.split(':');
      if (parts.length != 2) {
        continue;
      }

      final food = _findFood(parts.first);
      final quantity = int.tryParse(parts.last);
      if (food != null && quantity != null && quantity > 0) {
        _cartQuantities[food.id] = quantity.clamp(1, food.stockCount).toInt();
      }
    }
  }

  void _restorePurchaseRecords() {
    final encodedRecords =
        _preferences?.getStringList(_purchaseRecordsKey) ?? [];

    _purchaseRecords
      ..clear()
      ..addAll(
        encodedRecords.map(_decodePurchaseRecord).whereType<PurchaseRecord>(),
      );
  }

  void _restoreFoodFeedback() {
    final encodedFeedback = _preferences?.getStringList(_foodFeedbackKey) ?? [];

    _foodFeedback.clear();
    _ecoLeaderboard.clear();
    for (final encodedItem in encodedFeedback) {
      try {
        final decoded = jsonDecode(encodedItem);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final feedback = FoodFeedback.fromJson(decoded);
        if (feedback.foodId.isNotEmpty && _findFood(feedback.foodId) != null) {
          _foodFeedback[feedback.foodId] = feedback;
        }
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
  }

  FoodItem? _findFood(String foodId) {
    for (final food in _catalog.allFoods) {
      if (food.id == foodId) {
        return food;
      }
    }

    final favorite = _favorites[foodId];
    if (favorite != null) return favorite;
    for (final food in _history) {
      if (food.id == foodId) return food;
    }

    return null;
  }

  void _persistFavorites() {
    unawaited(
      _preferences?.setStringList(_favoriteIdsKey, _favorites.keys.toList()),
    );
  }

  void _persistHistory() {
    unawaited(
      _preferences?.setStringList(
        _historyIdsKey,
        _history.map((food) => food.id).toList(),
      ),
    );
  }

  void _persistSearchLogs() {
    unawaited(
      _preferences?.setStringList(
        _searchLogsKey,
        _searchLogs.map((log) => jsonEncode(log.toJson())).toList(),
      ),
    );
  }

  void _persistCartItems() {
    unawaited(
      _preferences?.setStringList(
        _cartItemsKey,
        _cartQuantities.entries
            .map((entry) => '${entry.key}:${entry.value}')
            .toList(),
      ),
    );
  }

  void _persistPurchaseRecords() {
    unawaited(
      _preferences?.setStringList(
        _purchaseRecordsKey,
        _purchaseRecords.map(_encodePurchaseRecord).toList(),
      ),
    );
  }

  void _persistFoodFeedback() {
    unawaited(
      _preferences?.setStringList(
        _foodFeedbackKey,
        _foodFeedback.values
            .map((feedback) => jsonEncode(feedback.toJson()))
            .toList(),
      ),
    );
  }

  int _ecoPointsForCartItem(CartItem item) {
    final basePoints = (item.food.ecoPriorityScore * 10).round();
    final expiringBonus = item.food.isExpiringSoon ? 8 : 2;
    return (basePoints + expiringBonus) * item.quantity;
  }

  String _encodePurchaseRecord(PurchaseRecord record) {
    return jsonEncode({
      'id': record.id,
      'purchasedAt': record.purchasedAt.toIso8601String(),
      'items': record.items
          .map((item) => {'foodId': item.food.id, 'quantity': item.quantity})
          .toList(),
    });
  }

  PurchaseRecord? _decodePurchaseRecord(String encodedRecord) {
    try {
      final decoded = jsonDecode(encodedRecord);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final id = decoded['id'] as String?;
      final purchasedAtText = decoded['purchasedAt'] as String?;
      final itemMaps = decoded['items'] as List?;

      if (id == null || purchasedAtText == null || itemMaps == null) {
        return null;
      }

      final items = <CartItem>[];
      for (final itemMap in itemMaps) {
        if (itemMap is! Map<String, dynamic>) {
          continue;
        }

        final foodId = itemMap['foodId'] as String?;
        final quantity = itemMap['quantity'] as int?;
        final food = foodId == null ? null : _findFood(foodId);
        if (food != null && quantity != null && quantity > 0) {
          items.add(CartItem(food: food, quantity: quantity));
        }
      }

      if (items.isEmpty) {
        return null;
      }

      return PurchaseRecord(
        id: id,
        purchasedAt: DateTime.parse(purchasedAtText),
        items: items,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @visibleForTesting
  void clearForTesting() {
    _generation++;
    _busy = false;
    cloudLoaded = false;
    _pendingCheckout = null;
    _pendingCorrupt = false;
    _ordersCursor = null;
    errorMessage = null;
    _favorites.clear();
    _history.clear();
    _searchLogs.clear();
    _cartQuantities.clear();
    _purchaseRecords.clear();
    _foodFeedback.clear();
    unawaited(_preferences?.remove(_favoriteIdsKey));
    unawaited(_preferences?.remove(_historyIdsKey));
    unawaited(_preferences?.remove(_searchLogsKey));
    unawaited(_preferences?.remove(_cartItemsKey));
    unawaited(_preferences?.remove(_purchaseRecordsKey));
    unawaited(_preferences?.remove(_foodFeedbackKey));
    unawaited(_preferences?.remove(_pendingKey));
    notifyListeners();
  }
}
