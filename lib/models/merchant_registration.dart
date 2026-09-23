class MerchantRegistration {
  const MerchantRegistration({
    required this.email,
    required this.password,
    required this.businessName,
    required this.contactPhone,
  });
  final String email, password, businessName, contactPhone;
  Map<String, Object?> toJson() => {
    'email': email,
    'password': password,
    'businessName': businessName,
    'contactPhone': contactPhone,
  };
}
