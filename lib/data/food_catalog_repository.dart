import 'package:my_app/data/mock_food_repository.dart';
import 'package:my_app/models/convenience_store.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/services/catalog_api.dart';
import 'package:my_app/services/member_api.dart';

class FoodCatalogRepository {
  FoodCatalogRepository({required this.useCloud, CatalogApi? api})
    : _api = api ?? CatalogApi();
  static final instance = FoodCatalogRepository(
    useCloud: const bool.fromEnvironment('CLOUD_CATALOG'),
  );
  final bool useCloud;
  final CatalogApi _api;
  List<FoodItem> _foods = const [];
  bool isLoaded = false;
  List<FoodItem> get allFoods =>
      useCloud ? _foods : MockFoodRepository.allFoods;

  Future<void> load() async {
    if (!useCloud) return;
    final loaded = <FoodItem>[];
    final ids = <String>{};
    final cursors = <String>{};
    String? cursor;
    do {
      final page = await _api.page(after: cursor);
      for (final food in page.items) {
        if (!ids.add(food.id)) throw const MemberApiException('商品分頁資料重複，請重新整理');
        loaded.add(food);
      }
      cursor = page.nextCursor;
      if (cursor != null && !cursors.add(cursor)) {
        throw const MemberApiException('商品分頁回應異常');
      }
      if (loaded.length > 5000 ||
          (loaded.length >= 5000 && cursor != null) ||
          cursors.length > 100) {
        throw const MemberApiException('商品數量超過目前載入上限，請聯絡管理者');
      }
    } while (cursor != null);
    // Publish a complete result only; a partial/failed fetch never becomes the catalogue.
    _foods = List.unmodifiable(loaded);
    isLoaded = true;
  }

  List<ConvenienceStore> get convenienceStores {
    if (!useCloud) return MockFoodRepository.convenienceStores;
    final stores = <String, ConvenienceStore>{};
    for (final food in allFoods) {
      final brand = switch (food.storeBrand?.toLowerCase()) {
        '7-11' || '7-eleven' => ConvenienceBrand.sevenEleven,
        '全家' || '全家便利商店' || 'familymart' => ConvenienceBrand.familyMart,
        _ => null,
      };
      if (brand == null || !food.hasDistance) continue;
      stores[food.storeId] = ConvenienceStore(
        id: food.storeId,
        brand: brand,
        name: food.storeName,
        address: food.storeAddress,
        distanceMeters: food.distanceMeters,
        walkingMinutes: (food.distanceMeters / 75).ceil(),
        businessHours: food.businessHours,
        businessWeekdays: food.businessWeekdays,
        contactPhone: food.contactPhone,
      );
    }
    return List.unmodifiable(stores.values);
  }

  List<ConvenienceStore> convenienceStoresByBrand(
    ConvenienceBrand? brand, {
    int? maxDistanceMeters,
  }) => convenienceStores
      .where(
        (store) =>
            (brand == null || store.brand == brand) &&
            (maxDistanceMeters == null ||
                store.distanceMeters <= maxDistanceMeters),
      )
      .toList();

  List<FoodItem> expiringFoodsByBrand(
    ConvenienceBrand? brand, {
    int? maxDistanceMeters,
  }) {
    final storeIds = convenienceStoresByBrand(
      brand,
      maxDistanceMeters: maxDistanceMeters,
    ).map((store) => store.id).toSet();
    return allFoods
        .where(
          (food) =>
              food.isExpiringSoon &&
              storeIds.contains(food.storeId) &&
              (maxDistanceMeters == null ||
                  food.distanceMeters <= maxDistanceMeters),
        )
        .toList();
  }

  List<FoodItem> expiringFoodsByStore(String storeId) => allFoods
      .where((food) => food.isExpiringSoon && food.storeId == storeId)
      .toList();
}
