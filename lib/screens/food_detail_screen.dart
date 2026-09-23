import 'package:flutter/material.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/screens/cart_screen.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/widgets/food_info_tag.dart';
import 'package:my_app/widgets/food_photo.dart';

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({super.key, required this.food});

  final FoodItem food;

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  static const List<String> _feedbackTags = [
    '份量剛好',
    '價格合理',
    '會再回購',
    '太油',
    '不符合偏好',
  ];

  final UserActivityService _activityService = UserActivityService.instance;
  final Set<String> _selectedFeedbackTags = {};
  int _selectedRating = 0;

  FoodItem get food => widget.food;

  @override
  void initState() {
    super.initState();
    _activityService.addListener(_refresh);
    final feedback = _activityService.feedbackFor(food.id);
    if (feedback != null) {
      _selectedRating = feedback.rating;
      _selectedFeedbackTags.addAll(feedback.tags);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activityService.addHistory(food);
    });
  }

  @override
  void dispose() {
    _activityService.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '餐點資訊',
          style: TextStyle(
            color: Color(0xFF2E3A2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildHero(),
            const SizedBox(height: 16),
            _buildRecommendationReason(),
            const SizedBox(height: 16),
            _buildInfoGrid(),
            const SizedBox(height: 16),
            _buildNutritionSection(),
            const SizedBox(height: 16),
            _buildTagSection('食材資訊', food.ingredients),
            const SizedBox(height: 16),
            _buildTagSection('營養與偏好標籤', food.nutritionTags + food.tags),
            const SizedBox(height: 16),
            _buildFeedbackSection(),
            const SizedBox(height: 16),
            _buildStoreInfo(),
            const SizedBox(height: 20),
            _buildActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FoodPhoto(
                  food: food,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  borderRadius: 18,
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            food.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            food.storeName,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FoodInfoTag(text: food.category),
              if (food.specialLabel != null)
                FoodInfoTag(text: food.specialLabel!, warning: true),
              FoodInfoTag(text: food.priceLabel),
              if (food.discountLabel != null)
                FoodInfoTag(text: food.discountLabel!, warning: true),
              if (food.isExpiringSoon)
                FoodInfoTag(text: food.timeLeftLabel, warning: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationReason() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4E8D57)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '推薦原因',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  food.recommendationReason,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4E8D57),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildInfoTile(Icons.payments_rounded, '價格', _priceDetail),
        _buildInfoTile(Icons.place_rounded, '距離', food.distanceLabel),
        _buildInfoTile(Icons.inventory_2_rounded, '庫存', '${food.stockCount} 份'),
        _buildInfoTile(
          Icons.eco_rounded,
          '減廢分數',
          '${(food.ecoPriorityScore * 100).round()} 分',
          onTap: _showEcoScoreExplanation,
        ),
      ],
    );
  }

  String get _priceDetail {
    if (food.originalPrice == null) {
      return food.priceLabel;
    }

    return '${food.priceLabel} / 原價 NT\$ ${food.originalPrice}';
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4E8D57), size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A2F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEcoScoreExplanation() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Text(
            '減廢分數用來排序較需要優先被購買的餐點。分數綜合即期狀態、距保存期限的時間、折扣幅度與庫存等資料；分數越高，代表優先購買越有助於降低浪費。缺少資料時不會自行推測，因此分數可能較低。',
            style: TextStyle(height: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionSection() {
    return _buildSection(
      title: '營養估算',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildNutritionTile(
                  Icons.local_fire_department_rounded,
                  '熱量',
                  food.caloriesLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNutritionTile(
                  Icons.scale_rounded,
                  '重量',
                  food.weightLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildNutritionTile(
                  Icons.fitness_center_rounded,
                  '蛋白質',
                  food.proteinLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNutritionTile(
                  Icons.water_drop_rounded,
                  '脂肪',
                  food.fatLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNutritionTile(
                  Icons.grain_rounded,
                  '碳水',
                  food.carbsLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4E8D57)),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A2F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection(String title, List<String> values) {
    return _buildSection(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .toSet()
            .map((value) => FoodInfoTag(text: value))
            .toList(),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final savedFeedback = _activityService.feedbackFor(food.id);

    return _buildSection(
      title: '餐後回饋',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) {
              final rating = index + 1;
              final isSelected = rating <= _selectedRating;

              return IconButton(
                key: ValueKey('feedback-star-$rating'),
                onPressed: () {
                  setState(() {
                    _selectedRating = rating;
                  });
                },
                icon: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isSelected ? const Color(0xFFF5A623) : Colors.black26,
                ),
                tooltip: '$rating 星',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              );
            }),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _feedbackTags.map((tag) {
              final isSelected = _selectedFeedbackTags.contains(tag);

              return FilterChip(
                key: ValueKey('feedback-tag-$tag'),
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFeedbackTags.add(tag);
                    } else {
                      _selectedFeedbackTags.remove(tag);
                    }
                  });
                },
                selectedColor: const Color(0xFFDDEEDB),
                checkmarkColor: const Color(0xFF4E8D57),
                side: const BorderSide(color: Color(0xFFC9D8C4)),
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xFF2F6B3C)
                      : const Color(0xFF2E3A2F),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('save-food-feedback'),
              onPressed: _selectedRating == 0 ? null : _saveFeedback,
              icon: const Icon(Icons.rate_review_rounded),
              label: const Text('儲存回饋'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4E8D57),
                disabledBackgroundColor: const Color(0xFFE4E9E1),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.black38,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (savedFeedback != null) ...[
            const SizedBox(height: 10),
            Text(
              '已送出 ${savedFeedback.ratingLabel}回饋：${savedFeedback.tagSummary}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4E8D57),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreInfo() {
    return _buildSection(
      title: '店家資訊',
      child: Column(
        children: [
          _buildStoreRow(Icons.storefront_rounded, food.storeName),
          _buildStoreRow(Icons.location_on_rounded, food.storeAddress),
          _buildStoreRow(Icons.schedule_rounded, food.businessScheduleLabel),
          _buildStoreRow(Icons.call_rounded, food.contactPhone),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStoreRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4E8D57)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2E3A2F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final isFavorite = _activityService.isFavorite(food.id);
    final isInCart = _activityService.isInCart(food.id);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _activityService.isFavoriteBusy(food.id)
                ? null
                : () async {
                    final saved = await _activityService.toggleFavorite(food);
                    if (!saved || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isFavorite
                              ? '已將 ${food.name} 移出收藏'
                              : '已將 ${food.name} 加入收藏',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            label: Text(
              _activityService.isFavoriteBusy(food.id)
                  ? '同步中'
                  : isFavorite
                  ? '取消收藏'
                  : '加入收藏',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4E8D57),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: food.stockCount <= 0
                ? null
                : isInCart
                ? _goToCart
                : _addToCart,
            icon: Icon(
              isInCart
                  ? Icons.shopping_cart_checkout_rounded
                  : Icons.add_shopping_cart_rounded,
            ),
            label: Text(
              food.stockCount <= 0
                  ? '已售完'
                  : isInCart
                  ? '查看購物車'
                  : '加入購物車',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4E8D57),
              side: const BorderSide(color: Color(0xFF4E8D57)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addToCart() {
    _activityService.addToCart(food);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已將 ${food.name} 加入購物車'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _goToCart() {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
    );
  }

  void _saveFeedback() {
    _activityService.saveFoodFeedback(
      food: food,
      rating: _selectedRating,
      tags: _selectedFeedbackTags.toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已儲存 ${food.name} 的餐點回饋'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
