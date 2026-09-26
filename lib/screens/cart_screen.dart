import 'package:flutter/material.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/cart_item.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/widgets/checkout_success_overlay.dart';
import 'package:my_app/widgets/food_photo.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.onCheckoutComplete, this.activity});

  final VoidCallback? onCheckoutComplete;
  final UserActivityService? activity;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final UserActivityService _activityService =
      widget.activity ?? UserActivityService.instance;

  @override
  void initState() {
    super.initState();
    _activityService.addListener(_refresh);
  }

  @override
  void dispose() {
    _activityService.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _activityService.cartItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '購物車',
          style: TextStyle(
            color: Color(0xFF2E3A2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
      ),
      body: SafeArea(
        child: _activityService.checkoutNeedsReview
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('待確認訂單資料異常，已暫停下單。請聯絡管理者確認。'),
                ),
              )
            : cartItems.isEmpty && !_activityService.hasPendingCheckout
            ? _buildEmptyState()
            : Column(
                children: [
                  Expanded(child: _buildCartList(cartItems)),
                  _buildCheckoutPanel(),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF4E8D57),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '購物車是空的',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A2F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '到餐點資訊頁加入想購買的商品，就能在這裡調整數量與結帳。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartList(List<CartItem> cartItems) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final item = cartItems[index];
        return Dismissible(
          key: ValueKey('cart-${item.food.id}'),
          direction: _activityService.cartLocked
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.only(right: 24),
            alignment: Alignment.centerRight,
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          onDismissed: (_) => _activityService.setCartQuantity(item.food, 0),
          child: _buildCartTile(item),
        );
      },
    );
  }

  Widget _buildCartTile(CartItem item) {
    final food = item.food;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          FoodPhoto(food: food, width: 58, height: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${food.storeName} / ${food.priceLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildQuantityControl(item),
        ],
      ),
    );
  }

  Widget _buildQuantityControl(CartItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: _activityService.cartLocked
              ? null
              : () => _activityService.decreaseCartItem(item.food),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed:
              _activityService.cartLocked ||
                  item.quantity >= item.food.stockCount
              ? null
              : () => _activityService.increaseCartItem(item.food),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  Widget _buildCheckoutPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5EDE2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('商品數量', style: TextStyle(color: Colors.black54)),
              ),
              Text(
                '${_activityService.checkoutQuantity} 項',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3A2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('總金額', style: TextStyle(color: Colors.black54)),
              ),
              Text(
                _activityService.hasPendingCheckout
                    ? '等待訂單確認'
                    : 'NT\$ ${_activityService.cartTotalPrice}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3A2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _activityService.canCheckout ? _checkout : null,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                _activityService.isSyncing
                    ? '處理中'
                    : _activityService.hasPendingCheckout
                    ? '確認上次訂單'
                    : _activityService.isCloud
                    ? '送出模擬訂單'
                    : '結帳',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkout() async {
    final record = await _activityService.submitCart();
    if (record == null || !mounted) {
      return;
    }

    _activityService.applyCheckoutStock(record);

    if (FoodCatalogRepository.instance.useCloud) {
      await FoodCatalogRepository.instance.load();
      await _activityService.refreshCloud();
      if (!mounted) return;
    }

    await showCheckoutSuccess(context, record);
    if (!mounted) return;

    widget.onCheckoutComplete?.call();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
