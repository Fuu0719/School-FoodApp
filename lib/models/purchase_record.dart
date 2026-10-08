import 'package:my_app/models/cart_item.dart';

class PurchaseRecord {
  const PurchaseRecord({
    required this.id,
    required this.purchasedAt,
    required this.items,
    this.cloudEcoPoints,
    this.cloudSavedAmount,
    this.paymentStatus = 'not_processed',
    this.checkoutUrl,
  });

  final String id;
  final DateTime purchasedAt;
  final List<CartItem> items;
  final int? cloudEcoPoints;
  final int? cloudSavedAmount;
  final String paymentStatus;
  final String? checkoutUrl;
  bool get isCloud => cloudEcoPoints != null;

  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  int get totalPrice {
    return items.fold(0, (sum, item) => sum + item.subtotal);
  }

  String get purchasedAtLabel {
    final month = purchasedAt.month.toString().padLeft(2, '0');
    final day = purchasedAt.day.toString().padLeft(2, '0');
    final hour = purchasedAt.hour.toString().padLeft(2, '0');
    final minute = purchasedAt.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String get summaryLabel => '$totalQuantity 項 / NT\$ $totalPrice';
}
