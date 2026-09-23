class MerchantAccount {
  const MerchantAccount({
    required this.id,
    required this.businessName,
    required this.email,
    required this.contactPhone,
    required this.allowedStoreNames,
    this.stores = const [],
  });

  final String id;
  final String businessName;
  final String email;
  final String contactPhone;
  final List<String> allowedStoreNames;
  final List<MerchantStore> stores;

  factory MerchantAccount.fromJson(Map<String, dynamic> json) {
    final stores = (json['stores'] as List)
        .map((row) => MerchantStore.fromJson(row as Map<String, dynamic>))
        .toList();
    return MerchantAccount(
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      email: json['email'] as String,
      contactPhone: json['contactPhone'] as String,
      stores: List.unmodifiable(stores),
      allowedStoreNames: List.unmodifiable(stores.map((store) => store.name)),
    );
  }

  String get primaryStoreName {
    return allowedStoreNames.isEmpty ? businessName : allowedStoreNames.first;
  }

  MerchantAccount copyWith({
    String? id,
    String? businessName,
    String? email,
    String? contactPhone,
    List<String>? allowedStoreNames,
  }) {
    return MerchantAccount(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      contactPhone: contactPhone ?? this.contactPhone,
      allowedStoreNames: allowedStoreNames ?? this.allowedStoreNames,
      stores: stores,
    );
  }

  static const demo = MerchantAccount(
    id: 'merchant-demo',
    businessName: '銘傳校園示範商家',
    email: 'store@mcu-food.local',
    contactPhone: '03-350-7001',
    allowedStoreNames: ['全家龜山銘美店', '7-11 龜山銘傳門市'],
  );
}

class MerchantStore {
  const MerchantStore({
    required this.id,
    required this.name,
    required this.address,
    required this.businessHours,
    this.contactPhone = '',
    this.businessWeekdays = const [],
    this.distanceMeters,
  });
  final String id, name, address, businessHours, contactPhone;
  final List<int> businessWeekdays;
  final int? distanceMeters;
  factory MerchantStore.fromJson(Map<String, dynamic> json) => MerchantStore(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    businessHours: json['businessHours'] as String,
    contactPhone: json['contactPhone'] as String? ?? '',
    businessWeekdays: List<int>.unmodifiable(
      (json['businessWeekdays'] as List? ?? const []).cast<int>(),
    ),
    distanceMeters: json['distanceMeters'] as int?,
  );
}
