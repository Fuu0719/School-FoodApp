class MerchantProductInput {
  const MerchantProductInput({
    required this.storeId,
    required this.name,
    required this.category,
    required this.price,
    this.originalPrice,
    required this.stockCount,
    required this.imageUrl,
    required this.calories,
    required this.weightGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    required this.tags,
    required this.ingredients,
    this.expiresAt,
    required this.isExpiringSoon,
  });
  final String storeId, name, category, imageUrl;
  final int price,
      stockCount,
      calories,
      weightGrams,
      proteinGrams,
      fatGrams,
      carbsGrams;
  final int? originalPrice;
  final List<String> tags, ingredients;
  final DateTime? expiresAt;
  final bool isExpiringSoon;
  factory MerchantProductInput.fromJson(Map<String, dynamic> json) =>
      MerchantProductInput(
        storeId: json['storeId'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        price: json['price'] as int,
        originalPrice: json['originalPrice'] as int?,
        stockCount: json['stockCount'] as int,
        imageUrl: json['imageUrl'] as String,
        calories: json['calories'] as int,
        weightGrams: json['weightGrams'] as int,
        proteinGrams: json['proteinGrams'] as int,
        fatGrams: json['fatGrams'] as int,
        carbsGrams: json['carbsGrams'] as int,
        tags: List<String>.unmodifiable(json['tags'] as List),
        ingredients: List<String>.unmodifiable(json['ingredients'] as List),
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.parse(json['expiresAt'] as String),
        isExpiringSoon: json['isExpiringSoon'] as bool,
      );
  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'name': name,
    'category': category,
    'price': price,
    'originalPrice': originalPrice,
    'stockCount': stockCount,
    'imageUrl': imageUrl,
    'calories': calories,
    'weightGrams': weightGrams,
    'proteinGrams': proteinGrams,
    'fatGrams': fatGrams,
    'carbsGrams': carbsGrams,
    'tags': tags,
    'ingredients': ingredients,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'isExpiringSoon': isExpiringSoon,
  };
}

class MerchantProduct {
  const MerchantProduct({
    required this.id,
    required this.storeName,
    required this.status,
    required this.revision,
    required this.input,
  });
  final String id, storeName, status;
  final int revision;
  final MerchantProductInput input;
  bool get isExpired =>
      status == 'active' &&
      input.expiresAt != null &&
      !input.expiresAt!.isAfter(DateTime.now());
  String get statusLabel => switch (status) {
    'active' when isExpired => '已過期',
    'active' => '已上架',
    'paused' => '已下架',
    'sold_out' => '已售完',
    _ => '草稿',
  };
  factory MerchantProduct.fromJson(Map<String, dynamic> json) =>
      MerchantProduct(
        id: json['id'] as String,
        storeName: json['storeName'] as String,
        status: json['status'] as String,
        revision: json['revision'] as int,
        input: MerchantProductInput.fromJson(json),
      );
}
