class MerchantRegistration {
  const MerchantRegistration({
    required this.email,
    required this.password,
    required this.businessName,
    required this.storeName,
    required this.address,
    required this.businessHours,
    required this.contactPhone,
    required this.businessWeekdays,
  });
  final String email,
      password,
      businessName,
      storeName,
      address,
      businessHours,
      contactPhone;
  final List<int> businessWeekdays;
  Map<String, Object?> toJson() => {
    'email': email,
    'password': password,
    'businessName': businessName,
    'storeName': storeName,
    'address': address,
    'businessHours': businessHours,
    'contactPhone': contactPhone,
    'businessWeekdays': businessWeekdays,
  };
}
