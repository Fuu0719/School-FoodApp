import 'package:flutter/material.dart';
import 'package:my_app/models/convenience_store.dart';
import 'package:my_app/models/food_item.dart';

class MockFoodRepository {
  static final DateTime _now = DateTime.now();

  static final List<FoodItem> allFoods = List.unmodifiable([
    ...List.generate(74, _buildFood),
    ..._convenienceExpiringFoods,
  ]);

  static const List<ConvenienceStore> convenienceStores = _convenienceStores;

  static List<FoodItem> get recommendedPreview => allFoods.take(2).toList();

  static List<FoodItem> get expiringFoods {
    return _convenienceExpiringFoods;
  }

  static List<FoodItem> expiringFoodsByBrand(
    ConvenienceBrand? brand, {
    int? maxDistanceMeters,
  }) {
    if (brand == null) {
      return expiringFoods
          .where(
            (food) =>
                maxDistanceMeters == null ||
                food.distanceMeters <= maxDistanceMeters,
          )
          .toList();
    }

    final storeIds = convenienceStores
        .where((store) => store.brand == brand)
        .map((store) => store.id)
        .toSet();
    return expiringFoods
        .where(
          (food) =>
              storeIds.contains(food.storeId) &&
              (maxDistanceMeters == null ||
                  food.distanceMeters <= maxDistanceMeters),
        )
        .toList();
  }

  static List<FoodItem> expiringFoodsByStore(String storeId) {
    return expiringFoods.where((food) => food.storeId == storeId).toList();
  }

  static List<ConvenienceStore> convenienceStoresByBrand(
    ConvenienceBrand? brand, {
    int? maxDistanceMeters,
  }) {
    return convenienceStores
        .where(
          (store) =>
              (brand == null || store.brand == brand) &&
              (maxDistanceMeters == null ||
                  store.distanceMeters <= maxDistanceMeters),
        )
        .toList();
  }

  static final List<FoodItem> _convenienceExpiringFoods = List.unmodifiable(
    List.generate(_convenienceFoodTemplates.length, _buildConvenienceFood),
  );

  static FoodItem _buildFood(int index) {
    final templateIndex = index % _foodTemplates.length;
    final batchIndex = index ~/ _foodTemplates.length;
    final template = _foodTemplates[templateIndex];
    final store = _stores[(templateIndex * 7 + batchIndex) % _stores.length];
    final price = _priceTiers[index % _priceTiers.length];
    final distance = _distanceTiers[(index * 3) % _distanceTiers.length];
    const isExpiringSoon = false;
    final stockCount = 3 + (index % 12);
    final suffix = _nameSuffixes[batchIndex % _nameSuffixes.length];
    final tags = _tagsWithExpiry(template.tags, isExpiringSoon);
    final nutrition = _nutritionFor(template.category, index);

    return FoodItem(
      id: 'food-${(index + 1).toString().padLeft(3, '0')}',
      name: '${template.name}$suffix',
      storeId: store.id,
      storeName: store.name,
      merchantName: store.name,
      storeAddress: store.address,
      businessHours: store.businessHours,
      businessWeekdays: store.businessWeekdays,
      contactPhone: store.contactPhone,
      price: price,
      originalPrice: null,
      discountLabel: null,
      category: template.category,
      tags: tags,
      ingredients: template.ingredients,
      nutritionTags: template.nutritionTags,
      calories: nutrition.calories,
      weightGrams: nutrition.weightGrams,
      proteinGrams: nutrition.proteinGrams,
      fatGrams: nutrition.fatGrams,
      carbsGrams: nutrition.carbsGrams,
      distanceMeters: distance,
      stockCount: stockCount,
      expiresAt: null,
      isExpiringSoon: isExpiringSoon,
      ecoPriorityScore: 0.35 + ((index % 20) * 0.015),
      recommendationReason: _buildReason(tags, price, distance, isExpiringSoon),
      imageUrl: _imageUrlFor(template.category, index),
      icon: template.icon,
      specialLabel: _specialLabelFor(index),
    );
  }

  static List<String> _tagsWithExpiry(
    List<String> source,
    bool isExpiringSoon,
  ) {
    if (!isExpiringSoon) {
      return List.unmodifiable(source);
    }

    if (source.contains('即期優惠')) {
      return List.unmodifiable(source);
    }

    if (source.length < 3) {
      return List.unmodifiable([...source, '即期優惠']);
    }

    return List.unmodifiable([...source.take(2), '即期優惠']);
  }

  static String _buildReason(
    List<String> tags,
    int price,
    int distance,
    bool isExpiringSoon,
  ) {
    final preferenceText = tags.take(2).join('與');
    final distanceText = distance <= 800 ? '距離近' : '仍在可接受距離內';
    final budgetText = price <= 150 ? '符合常見預算' : '適合預算較高時選擇';

    if (isExpiringSoon) {
      return '$preferenceText，且為即期優惠商品，可協助減少浪費';
    }

    return '$preferenceText，$budgetText，$distanceText';
  }

  static FoodItem _buildConvenienceFood(int index) {
    final template = _convenienceFoodTemplates[index];
    final store = convenienceStores.firstWhere(
      (store) => store.id == template.storeId,
    );
    final nutrition = _nutritionFor(template.category, index);

    return FoodItem(
      id: 'expiring-${(index + 1).toString().padLeft(3, '0')}',
      name: template.name,
      storeId: store.id,
      storeName: store.name,
      merchantName: store.name,
      storeAddress: store.address,
      businessHours: store.businessHours,
      businessWeekdays: store.businessWeekdays,
      contactPhone: store.contactPhone,
      price: template.price,
      originalPrice: template.originalPrice,
      discountLabel: template.discountLabel,
      category: template.category,
      tags: _tagsWithExpiry(template.tags, true),
      ingredients: template.ingredients,
      nutritionTags: template.nutritionTags,
      calories: nutrition.calories,
      weightGrams: nutrition.weightGrams,
      proteinGrams: nutrition.proteinGrams,
      fatGrams: nutrition.fatGrams,
      carbsGrams: nutrition.carbsGrams,
      distanceMeters: store.distanceMeters,
      stockCount: template.stockCount,
      expiresAt: _now.add(Duration(hours: template.expiresInHours)),
      isExpiringSoon: true,
      ecoPriorityScore: 0.85 + ((index % 6) * 0.02),
      recommendationReason:
          '${store.brandLabel} ${store.name} 即期品，${template.discountLabel} 並剩餘 ${template.stockCount} 份',
      imageUrl: _imageUrlFor(template.category, index + 200),
      icon: template.icon,
      specialLabel: '即期惜食',
    );
  }

  static String? _specialLabelFor(int index) {
    return switch (index % 12) {
      0 || 4 => '今日特餐',
      7 => '隱藏版',
      10 => '人氣回購',
      _ => null,
    };
  }

  static String _imageUrlFor(String category, int index) {
    final urls = _categoryImageUrls[category] ?? _categoryImageUrls['便當']!;
    return urls[index % urls.length];
  }

  static _NutritionEstimate _nutritionFor(String category, int index) {
    final base = switch (category) {
      '便當' => const _NutritionEstimate(
        calories: 560,
        weightGrams: 420,
        proteinGrams: 31,
        fatGrams: 17,
        carbsGrams: 68,
      ),
      '麵食' => const _NutritionEstimate(
        calories: 620,
        weightGrams: 430,
        proteinGrams: 27,
        fatGrams: 19,
        carbsGrams: 86,
      ),
      '飯糰' => const _NutritionEstimate(
        calories: 230,
        weightGrams: 115,
        proteinGrams: 9,
        fatGrams: 5,
        carbsGrams: 39,
      ),
      '輕食' => const _NutritionEstimate(
        calories: 330,
        weightGrams: 280,
        proteinGrams: 24,
        fatGrams: 11,
        carbsGrams: 30,
      ),
      '湯品' => const _NutritionEstimate(
        calories: 260,
        weightGrams: 360,
        proteinGrams: 18,
        fatGrams: 8,
        carbsGrams: 24,
      ),
      '甜點' => const _NutritionEstimate(
        calories: 280,
        weightGrams: 150,
        proteinGrams: 7,
        fatGrams: 12,
        carbsGrams: 38,
      ),
      _ => const _NutritionEstimate(
        calories: 420,
        weightGrams: 300,
        proteinGrams: 20,
        fatGrams: 14,
        carbsGrams: 48,
      ),
    };

    return _NutritionEstimate(
      calories: base.calories + (index % 5) * 12,
      weightGrams: base.weightGrams + (index % 4) * 15,
      proteinGrams: base.proteinGrams + (index % 3) * 2,
      fatGrams: base.fatGrams + (index % 3),
      carbsGrams: base.carbsGrams + (index % 4) * 4,
    );
  }
}

class _NutritionEstimate {
  const _NutritionEstimate({
    required this.calories,
    required this.weightGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
  });

  final int calories;
  final int weightGrams;
  final int proteinGrams;
  final int fatGrams;
  final int carbsGrams;
}

class _FoodTemplate {
  const _FoodTemplate({
    required this.name,
    required this.category,
    required this.tags,
    required this.ingredients,
    required this.nutritionTags,
    required this.icon,
  });

  final String name;
  final String category;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> nutritionTags;
  final IconData icon;
}

class _StoreTemplate {
  const _StoreTemplate({
    required this.id,
    required this.name,
    required this.address,
    required this.businessHours,
    required this.businessWeekdays,
    required this.contactPhone,
  });

  final String id;
  final String name;
  final String address;
  final String businessHours;
  final List<int> businessWeekdays;
  final String contactPhone;
}

class _ConvenienceFoodTemplate {
  const _ConvenienceFoodTemplate({
    required this.storeId,
    required this.name,
    required this.category,
    required this.tags,
    required this.ingredients,
    required this.nutritionTags,
    required this.price,
    required this.originalPrice,
    required this.discountLabel,
    required this.stockCount,
    required this.expiresInHours,
    required this.icon,
  });

  final String storeId;
  final String name;
  final String category;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> nutritionTags;
  final int price;
  final int originalPrice;
  final String discountLabel;
  final int stockCount;
  final int expiresInHours;
  final IconData icon;
}

const List<String> _nameSuffixes = ['', ' 經典', ' 主廚', ' 小份', ' 加量'];

const List<int> _priceTiers = [45, 60, 80, 100, 120, 140, 160, 180, 220, 260];

const List<int> _distanceTiers = [
  250,
  400,
  550,
  700,
  850,
  1000,
  1200,
  1500,
  1800,
  2200,
];

const Map<String, List<String>> _categoryImageUrls = {
  '便當': [
    'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=800&q=80',
  ],
  '飯糰': [
    'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?auto=format&fit=crop&w=800&q=80',
  ],
  '輕食': [
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
  ],
  '甜點': [
    'https://images.unsplash.com/photo-1551024506-0bccd828d307?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=800&q=80',
  ],
  '麵食': [
    'https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=800&q=80',
  ],
  '早餐': [
    'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1493770348161-369560ae357d?auto=format&fit=crop&w=800&q=80',
  ],
  '沙拉': [
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&w=800&q=80',
  ],
  '和食': [
    'https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1580822184713-fc5400e7fe10?auto=format&fit=crop&w=800&q=80',
  ],
  '韓式': [
    'https://images.unsplash.com/photo-1590301157890-4810ed352733?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?auto=format&fit=crop&w=800&q=80',
  ],
  '捲餅': [
    'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1562059390-a761a084768e?auto=format&fit=crop&w=800&q=80',
  ],
  '湯品': [
    'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1603105037880-880cd4edfb0d?auto=format&fit=crop&w=800&q=80',
  ],
};

const List<ConvenienceStore> _convenienceStores = [
  ConvenienceStore(
    id: 'seven-mcu',
    brand: ConvenienceBrand.sevenEleven,
    name: '7-11 龜山銘傳門市',
    address: '桃園市龜山區德明路152號154號1樓',
    distanceMeters: 180,
    walkingMinutes: 3,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-350-4227',
  ),
  ConvenienceStore(
    id: 'family-mingmei',
    brand: ConvenienceBrand.familyMart,
    name: '全家龜山銘美店',
    address: '桃園市龜山區德明路5號1樓',
    distanceMeters: 230,
    walkingMinutes: 4,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-319-7261',
  ),
  ConvenienceStore(
    id: 'family-de-ming',
    brand: ConvenienceBrand.familyMart,
    name: '全家龜山德明店',
    address: '桃園市龜山區德明路105號107號1樓',
    distanceMeters: 350,
    walkingMinutes: 5,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-350-9883',
  ),
  ConvenienceStore(
    id: 'family-mingyuan',
    brand: ConvenienceBrand.familyMart,
    name: '全家龜山銘園店',
    address: '桃園市龜山區德明路5號第二餐廳旁',
    distanceMeters: 420,
    walkingMinutes: 6,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-275-1213',
  ),
  ConvenienceStore(
    id: 'seven-tongming',
    brand: ConvenienceBrand.sevenEleven,
    name: '7-11 同銘門市',
    address: '桃園市龜山區大同路212號1樓',
    distanceMeters: 650,
    walkingMinutes: 9,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-359-5385',
  ),
  ConvenienceStore(
    id: 'family-mingcheng',
    brand: ConvenienceBrand.familyMart,
    name: '全家龜山銘成店',
    address: '桃園市龜山區大同路196號',
    distanceMeters: 720,
    walkingMinutes: 10,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-211-8462',
  ),
  ConvenienceStore(
    id: 'seven-dachuan',
    brand: ConvenienceBrand.sevenEleven,
    name: '7-11 大傳門市',
    address: '桃園市龜山區大同路357號357-1號1樓',
    distanceMeters: 950,
    walkingMinutes: 13,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-329-6730',
  ),
  ConvenienceStore(
    id: 'family-dachuan',
    brand: ConvenienceBrand.familyMart,
    name: '全家龜山大傳店',
    address: '桃園市龜山區大同路232號',
    distanceMeters: 1150,
    walkingMinutes: 16,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-349-2278',
  ),
  ConvenienceStore(
    id: 'seven-shanmin',
    brand: ConvenienceBrand.sevenEleven,
    name: '7-11 山民門市',
    address: '桃園市龜山區三民路100號',
    distanceMeters: 1450,
    walkingMinutes: 20,
    businessHours: '00:00-24:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '03-319-8039',
  ),
];

const List<_ConvenienceFoodTemplate> _convenienceFoodTemplates = [
  _ConvenienceFoodTemplate(
    storeId: 'seven-mcu',
    name: '鮪魚御飯糰',
    category: '飯糰',
    tags: ['輕食', '高蛋白'],
    ingredients: ['鮪魚', '海苔', '米飯'],
    nutritionTags: ['高蛋白', '輕食'],
    price: 26,
    originalPrice: 39,
    discountLabel: '65折',
    stockCount: 3,
    expiresInHours: 2,
    icon: Icons.rice_bowl_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-mcu',
    name: '舒肥雞胸餐盒 小份',
    category: '便當',
    tags: ['高蛋白', '低脂'],
    ingredients: ['雞胸肉', '毛豆', '糙米'],
    nutritionTags: ['高蛋白', '低脂'],
    price: 79,
    originalPrice: 120,
    discountLabel: '65折',
    stockCount: 2,
    expiresInHours: 3,
    icon: Icons.lunch_dining,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-mcu',
    name: '凱撒雞肉沙拉',
    category: '輕食',
    tags: ['低脂', '清爽'],
    ingredients: ['雞肉', '生菜', '麵包丁'],
    nutritionTags: ['低脂', '均衡'],
    price: 52,
    originalPrice: 79,
    discountLabel: '65折',
    stockCount: 4,
    expiresInHours: 4,
    icon: Icons.local_dining_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingmei',
    name: '明太子鮭魚飯糰',
    category: '飯糰',
    tags: ['高蛋白', '熱門'],
    ingredients: ['鮭魚', '明太子', '米飯'],
    nutritionTags: ['高蛋白'],
    price: 29,
    originalPrice: 45,
    discountLabel: '65折',
    stockCount: 2,
    expiresInHours: 2,
    icon: Icons.rice_bowl,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingmei',
    name: '烤雞三明治',
    category: '輕食',
    tags: ['高蛋白', '輕食'],
    ingredients: ['烤雞', '吐司', '生菜'],
    nutritionTags: ['高蛋白', '輕食'],
    price: 39,
    originalPrice: 59,
    discountLabel: '66折',
    stockCount: 5,
    expiresInHours: 3,
    icon: Icons.breakfast_dining,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingmei',
    name: '希臘優格杯',
    category: '甜點',
    tags: ['低脂', '清爽'],
    ingredients: ['優格', '莓果', '燕麥'],
    nutritionTags: ['低脂', '輕食'],
    price: 42,
    originalPrice: 65,
    discountLabel: '65折',
    stockCount: 3,
    expiresInHours: 4,
    icon: Icons.icecream,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-de-ming',
    name: '雞胸溫沙拉',
    category: '輕食',
    tags: ['高蛋白', '低脂'],
    ingredients: ['雞胸肉', '玉米', '花椰菜'],
    nutritionTags: ['高蛋白', '低脂'],
    price: 59,
    originalPrice: 89,
    discountLabel: '66折',
    stockCount: 4,
    expiresInHours: 2,
    icon: Icons.local_dining_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-de-ming',
    name: '起司雞肉飯糰',
    category: '飯糰',
    tags: ['高蛋白', '熱門'],
    ingredients: ['雞肉', '起司', '米飯'],
    nutritionTags: ['高蛋白'],
    price: 28,
    originalPrice: 42,
    discountLabel: '67折',
    stockCount: 1,
    expiresInHours: 1,
    icon: Icons.rice_bowl_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-de-ming',
    name: '蜂蜜鮮奶酪',
    category: '甜點',
    tags: ['甜點', '熱門'],
    ingredients: ['鮮奶', '蜂蜜', '吉利丁'],
    nutritionTags: ['甜點'],
    price: 35,
    originalPrice: 55,
    discountLabel: '64折',
    stockCount: 2,
    expiresInHours: 5,
    icon: Icons.cake_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingyuan',
    name: '香草烤雞餐盒',
    category: '便當',
    tags: ['高蛋白', '均衡'],
    ingredients: ['烤雞', '白飯', '青花菜'],
    nutritionTags: ['高蛋白', '均衡'],
    price: 85,
    originalPrice: 129,
    discountLabel: '66折',
    stockCount: 3,
    expiresInHours: 3,
    icon: Icons.lunch_dining,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingyuan',
    name: '鮮蔬蛋沙拉盒',
    category: '輕食',
    tags: ['均衡', '清爽'],
    ingredients: ['水煮蛋', '生菜', '番茄'],
    nutritionTags: ['均衡', '低脂'],
    price: 49,
    originalPrice: 75,
    discountLabel: '65折',
    stockCount: 2,
    expiresInHours: 4,
    icon: Icons.egg_alt_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingyuan',
    name: '抹茶紅豆杯',
    category: '甜點',
    tags: ['甜點', '清爽'],
    ingredients: ['抹茶', '紅豆', '鮮奶油'],
    nutritionTags: ['甜點'],
    price: 38,
    originalPrice: 58,
    discountLabel: '66折',
    stockCount: 4,
    expiresInHours: 5,
    icon: Icons.cake,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-tongming',
    name: '鮭魚豆皮飯糰',
    category: '飯糰',
    tags: ['高蛋白', '輕食'],
    ingredients: ['鮭魚', '豆皮', '米飯'],
    nutritionTags: ['高蛋白', '輕食'],
    price: 31,
    originalPrice: 48,
    discountLabel: '65折',
    stockCount: 2,
    expiresInHours: 2,
    icon: Icons.rice_bowl,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-tongming',
    name: '青醬雞肉義大利麵',
    category: '麵食',
    tags: ['高蛋白', '熱門'],
    ingredients: ['雞肉', '青醬', '義大利麵'],
    nutritionTags: ['高蛋白'],
    price: 72,
    originalPrice: 110,
    discountLabel: '65折',
    stockCount: 1,
    expiresInHours: 2,
    icon: Icons.restaurant,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-tongming',
    name: '水果優格杯 即期',
    category: '甜點',
    tags: ['低脂', '輕食'],
    ingredients: ['優格', '香蕉', '莓果'],
    nutritionTags: ['低脂', '輕食'],
    price: 39,
    originalPrice: 60,
    discountLabel: '65折',
    stockCount: 3,
    expiresInHours: 5,
    icon: Icons.icecream,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingcheng',
    name: '鮮蝦沙拉捲',
    category: '輕食',
    tags: ['低脂', '高蛋白'],
    ingredients: ['鮮蝦', '生菜', '餅皮'],
    nutritionTags: ['低脂', '高蛋白'],
    price: 55,
    originalPrice: 85,
    discountLabel: '65折',
    stockCount: 2,
    expiresInHours: 3,
    icon: Icons.wrap_text_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-mingcheng',
    name: '蔬食飯糰',
    category: '飯糰',
    tags: ['素食', '輕食'],
    ingredients: ['海苔', '菇類', '米飯'],
    nutritionTags: ['素食', '輕食'],
    price: 27,
    originalPrice: 42,
    discountLabel: '64折',
    stockCount: 4,
    expiresInHours: 4,
    icon: Icons.rice_bowl_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-dachuan',
    name: '韓式泡菜雞肉飯',
    category: '便當',
    tags: ['高蛋白', '微辣'],
    ingredients: ['雞肉', '泡菜', '米飯'],
    nutritionTags: ['高蛋白'],
    price: 82,
    originalPrice: 125,
    discountLabel: '66折',
    stockCount: 2,
    expiresInHours: 3,
    icon: Icons.ramen_dining_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-dachuan',
    name: '地瓜雞蛋盒',
    category: '輕食',
    tags: ['高纖', '均衡'],
    ingredients: ['地瓜', '水煮蛋', '毛豆'],
    nutritionTags: ['高纖', '均衡'],
    price: 46,
    originalPrice: 70,
    discountLabel: '66折',
    stockCount: 3,
    expiresInHours: 4,
    icon: Icons.egg_alt_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-dachuan',
    name: '黑糖燕麥奶酪',
    category: '甜點',
    tags: ['甜點', '熱門'],
    ingredients: ['燕麥', '牛奶', '黑糖'],
    nutritionTags: ['甜點'],
    price: 36,
    originalPrice: 55,
    discountLabel: '65折',
    stockCount: 1,
    expiresInHours: 5,
    icon: Icons.cake_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-dachuan',
    name: '炙燒雞肉飯糰',
    category: '飯糰',
    tags: ['高蛋白', '熱門'],
    ingredients: ['雞肉', '海苔', '米飯'],
    nutritionTags: ['高蛋白'],
    price: 30,
    originalPrice: 46,
    discountLabel: '65折',
    stockCount: 4,
    expiresInHours: 2,
    icon: Icons.rice_bowl_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-dachuan',
    name: '鮮蔬雞蛋三明治',
    category: '輕食',
    tags: ['均衡', '輕食'],
    ingredients: ['水煮蛋', '吐司', '生菜'],
    nutritionTags: ['均衡', '輕食'],
    price: 36,
    originalPrice: 55,
    discountLabel: '65折',
    stockCount: 2,
    expiresInHours: 4,
    icon: Icons.breakfast_dining,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'family-dachuan',
    name: '照燒雞腿餐盒',
    category: '便當',
    tags: ['高蛋白', '均衡'],
    ingredients: ['雞腿', '米飯', '青菜'],
    nutritionTags: ['高蛋白', '均衡'],
    price: 88,
    originalPrice: 135,
    discountLabel: '65折',
    stockCount: 1,
    expiresInHours: 3,
    icon: Icons.lunch_dining,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-shanmin',
    name: '鮭魚起司飯糰',
    category: '飯糰',
    tags: ['高蛋白', '輕食'],
    ingredients: ['鮭魚', '起司', '米飯'],
    nutritionTags: ['高蛋白', '輕食'],
    price: 32,
    originalPrice: 49,
    discountLabel: '65折',
    stockCount: 3,
    expiresInHours: 2,
    icon: Icons.rice_bowl,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-shanmin',
    name: '和風豆腐沙拉',
    category: '輕食',
    tags: ['素食', '清爽'],
    ingredients: ['豆腐', '生菜', '和風醬'],
    nutritionTags: ['素食', '低脂'],
    price: 48,
    originalPrice: 75,
    discountLabel: '64折',
    stockCount: 2,
    expiresInHours: 4,
    icon: Icons.spa_rounded,
  ),
  _ConvenienceFoodTemplate(
    storeId: 'seven-shanmin',
    name: '番茄肉醬義大利麵',
    category: '麵食',
    tags: ['熱門', '均衡'],
    ingredients: ['番茄', '絞肉', '義大利麵'],
    nutritionTags: ['均衡'],
    price: 78,
    originalPrice: 119,
    discountLabel: '66折',
    stockCount: 2,
    expiresInHours: 3,
    icon: Icons.restaurant,
  ),
];

const List<_FoodTemplate> _foodTemplates = [
  _FoodTemplate(
    name: '舒肥雞胸餐盒',
    category: '便當',
    tags: ['高蛋白', '低脂', '均衡'],
    ingredients: ['雞胸肉', '糙米', '花椰菜'],
    nutritionTags: ['高蛋白', '低脂'],
    icon: Icons.lunch_dining,
  ),
  _FoodTemplate(
    name: '蔬食藜麥便當',
    category: '便當',
    tags: ['素食', '高纖', '均衡'],
    ingredients: ['藜麥', '豆腐', '彩椒'],
    nutritionTags: ['高纖', '均衡'],
    icon: Icons.spa_rounded,
  ),
  _FoodTemplate(
    name: '鮭魚藜麥沙拉',
    category: '沙拉',
    tags: ['低脂', '均衡', '高蛋白'],
    ingredients: ['鮭魚', '藜麥', '生菜'],
    nutritionTags: ['低脂', '均衡'],
    icon: Icons.set_meal,
  ),
  _FoodTemplate(
    name: '鮮蝦酪梨沙拉',
    category: '沙拉',
    tags: ['低脂', '清爽', '高蛋白'],
    ingredients: ['鮮蝦', '酪梨', '蘿蔓生菜'],
    nutritionTags: ['低脂', '高蛋白'],
    icon: Icons.local_dining_rounded,
  ),
  _FoodTemplate(
    name: '日式豆腐和食',
    category: '和食',
    tags: ['素食', '均衡', '清爽'],
    ingredients: ['豆腐', '白飯', '海帶芽'],
    nutritionTags: ['均衡'],
    icon: Icons.rice_bowl,
  ),
  _FoodTemplate(
    name: '味噌鯖魚定食',
    category: '和食',
    tags: ['高蛋白', '均衡', '熱門'],
    ingredients: ['鯖魚', '味噌湯', '白飯'],
    nutritionTags: ['高蛋白', '均衡'],
    icon: Icons.rice_bowl_rounded,
  ),
  _FoodTemplate(
    name: '番茄雞肉義大利麵',
    category: '麵食',
    tags: ['高蛋白', '熱門', '均衡'],
    ingredients: ['雞肉', '番茄', '義大利麵'],
    nutritionTags: ['高蛋白'],
    icon: Icons.restaurant,
  ),
  _FoodTemplate(
    name: '香蒜菇菇義大利麵',
    category: '麵食',
    tags: ['素食', '清爽', '熱門'],
    ingredients: ['菇類', '蒜片', '義大利麵'],
    nutritionTags: ['均衡'],
    icon: Icons.restaurant_menu_rounded,
  ),
  _FoodTemplate(
    name: '鮪魚三明治',
    category: '早餐',
    tags: ['輕食', '高蛋白'],
    ingredients: ['鮪魚', '吐司', '生菜'],
    nutritionTags: ['輕食', '高蛋白'],
    icon: Icons.breakfast_dining,
  ),
  _FoodTemplate(
    name: '烤地瓜雞蛋盒',
    category: '早餐',
    tags: ['均衡', '高纖'],
    ingredients: ['地瓜', '水煮蛋', '毛豆'],
    nutritionTags: ['高纖', '均衡'],
    icon: Icons.egg_alt_rounded,
  ),
  _FoodTemplate(
    name: '水果優格杯',
    category: '甜點',
    tags: ['低脂', '輕食'],
    ingredients: ['優格', '香蕉', '莓果'],
    nutritionTags: ['低脂', '輕食'],
    icon: Icons.icecream,
  ),
  _FoodTemplate(
    name: '燕麥奶酪杯',
    category: '甜點',
    tags: ['低脂', '熱門'],
    ingredients: ['燕麥', '牛奶', '黑糖'],
    nutritionTags: ['低脂'],
    icon: Icons.cake_rounded,
  ),
  _FoodTemplate(
    name: '韓式泡菜雞肉飯',
    category: '韓式',
    tags: ['高蛋白', '微辣', '熱門'],
    ingredients: ['雞腿肉', '泡菜', '白飯'],
    nutritionTags: ['高蛋白'],
    icon: Icons.ramen_dining_rounded,
  ),
  _FoodTemplate(
    name: '韓式豆腐拌飯',
    category: '韓式',
    tags: ['素食', '微辣', '均衡'],
    ingredients: ['豆腐', '泡菜', '拌飯蔬菜'],
    nutritionTags: ['均衡'],
    icon: Icons.ramen_dining,
  ),
  _FoodTemplate(
    name: '南瓜濃湯套餐',
    category: '輕食',
    tags: ['清爽', '輕食', '均衡'],
    ingredients: ['南瓜', '牛奶', '全麥麵包'],
    nutritionTags: ['均衡'],
    icon: Icons.soup_kitchen_rounded,
  ),
  _FoodTemplate(
    name: '牛肉蔬菜捲',
    category: '輕食',
    tags: ['高蛋白', '輕食', '高纖'],
    ingredients: ['牛肉', '萵苣', '全麥餅皮'],
    nutritionTags: ['高蛋白', '高纖'],
    icon: Icons.wrap_text_rounded,
  ),
  _FoodTemplate(
    name: '墨西哥雞肉捲',
    category: '捲餅',
    tags: ['高蛋白', '微辣'],
    ingredients: ['雞肉', '莎莎醬', '餅皮'],
    nutritionTags: ['高蛋白'],
    icon: Icons.dinner_dining_rounded,
  ),
  _FoodTemplate(
    name: '彩蔬豆泥捲',
    category: '捲餅',
    tags: ['素食', '高纖'],
    ingredients: ['鷹嘴豆泥', '彩椒', '全麥餅皮'],
    nutritionTags: ['高纖'],
    icon: Icons.dining_rounded,
  ),
  _FoodTemplate(
    name: '藥膳雞湯',
    category: '湯品',
    tags: ['高蛋白', '清爽'],
    ingredients: ['雞腿', '枸杞', '藥膳湯底'],
    nutritionTags: ['高蛋白'],
    icon: Icons.soup_kitchen,
  ),
  _FoodTemplate(
    name: '番茄蔬菜湯',
    category: '湯品',
    tags: ['素食', '低脂', '清爽'],
    ingredients: ['番茄', '洋蔥', '高麗菜'],
    nutritionTags: ['低脂'],
    icon: Icons.local_cafe_rounded,
  ),
];

const List<_StoreTemplate> _stores = [
  _StoreTemplate(
    id: 'store-001',
    name: '健康餐盒店',
    address: '台北市中山區健康路 12 號',
    businessHours: '10:30-20:30',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ],
    contactPhone: '02-2500-1200',
  ),
  _StoreTemplate(
    id: 'store-002',
    name: '原味沙拉吧',
    address: '台北市大安區青田街 8 號',
    businessHours: '11:00-19:30',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '02-2700-0135',
  ),
  _StoreTemplate(
    id: 'store-003',
    name: '禾食堂',
    address: '台北市信義區松仁路 66 號',
    businessHours: '11:00-21:00',
    businessWeekdays: [
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ],
    contactPhone: '02-2720-0100',
  ),
  _StoreTemplate(
    id: 'store-004',
    name: '義式小館',
    address: '台北市中正區羅斯福路 120 號',
    businessHours: '11:30-21:30',
    businessWeekdays: [
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '02-2360-0150',
  ),
  _StoreTemplate(
    id: 'store-005',
    name: '晨光早餐店',
    address: '台北市松山區民生東路 35 號',
    businessHours: '06:30-13:00',
    businessWeekdays: [DateTime.friday, DateTime.saturday, DateTime.sunday],
    contactPhone: '02-2710-0045',
  ),
  _StoreTemplate(
    id: 'store-006',
    name: '輕食專賣店',
    address: '台北市大同區承德路 58 號',
    businessHours: '09:00-18:00',
    businessWeekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
    contactPhone: '02-2550-0060',
  ),
  _StoreTemplate(
    id: 'store-007',
    name: '綠意蔬食',
    address: '台北市大安區和平東路 88 號',
    businessHours: '10:30-20:00',
    businessWeekdays: [DateTime.tuesday, DateTime.thursday, DateTime.saturday],
    contactPhone: '02-2700-0088',
  ),
  _StoreTemplate(
    id: 'store-008',
    name: '首爾小食堂',
    address: '台北市萬華區成都路 22 號',
    businessHours: '11:00-21:30',
    businessWeekdays: [DateTime.saturday, DateTime.sunday],
    contactPhone: '02-2388-0220',
  ),
  _StoreTemplate(
    id: 'store-009',
    name: '暖食咖啡',
    address: '台北市中山區南京東路 45 號',
    businessHours: '08:00-18:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ],
    contactPhone: '02-2508-0045',
  ),
  _StoreTemplate(
    id: 'store-010',
    name: '活力捲餅',
    address: '台北市松山區八德路 99 號',
    businessHours: '10:00-19:30',
    businessWeekdays: [
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '02-2570-0099',
  ),
  _StoreTemplate(
    id: 'store-011',
    name: '巷口健康鋪',
    address: '台北市大同區迪化街 16 號',
    businessHours: '07:30-15:00',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ],
    contactPhone: '02-2556-0016',
  ),
  _StoreTemplate(
    id: 'store-012',
    name: '城市沙拉',
    address: '台北市信義區松壽路 18 號',
    businessHours: '10:30-20:30',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '02-2722-0018',
  ),
  _StoreTemplate(
    id: 'store-013',
    name: '巷弄義麵',
    address: '台北市大安區復興南路 66 號',
    businessHours: '11:30-22:00',
    businessWeekdays: [
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ],
    contactPhone: '02-2706-0066',
  ),
  _StoreTemplate(
    id: 'store-014',
    name: '米日食堂',
    address: '台北市中山區錦州街 21 號',
    businessHours: '11:00-20:30',
    businessWeekdays: [
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '02-2521-0021',
  ),
  _StoreTemplate(
    id: 'store-015',
    name: '晴天早午餐',
    address: '台北市松山區光復北路 30 號',
    businessHours: '07:00-14:30',
    businessWeekdays: [DateTime.friday, DateTime.saturday, DateTime.sunday],
    contactPhone: '02-2760-0030',
  ),
  _StoreTemplate(
    id: 'store-016',
    name: '蔬醒廚房',
    address: '台北市文山區木柵路 46 號',
    businessHours: '10:00-19:00',
    businessWeekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
    contactPhone: '02-2930-0046',
  ),
  _StoreTemplate(
    id: 'store-017',
    name: '辣味研究所',
    address: '台北市萬華區武昌街 57 號',
    businessHours: '12:00-22:00',
    businessWeekdays: [DateTime.tuesday, DateTime.thursday, DateTime.saturday],
    contactPhone: '02-2381-0057',
  ),
  _StoreTemplate(
    id: 'store-018',
    name: '週末湯屋',
    address: '台北市大安區信義路 155 號',
    businessHours: '11:00-19:00',
    businessWeekdays: [DateTime.saturday, DateTime.sunday],
    contactPhone: '02-2701-0155',
  ),
  _StoreTemplate(
    id: 'store-019',
    name: '木碗輕食',
    address: '台北市中正區杭州南路 19 號',
    businessHours: '08:30-17:30',
    businessWeekdays: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ],
    contactPhone: '02-2390-0019',
  ),
  _StoreTemplate(
    id: 'store-020',
    name: '晚餐盒子',
    address: '台北市信義區忠孝東路 520 號',
    businessHours: '16:00-22:30',
    businessWeekdays: [
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    contactPhone: '02-2720-0520',
  ),
];
