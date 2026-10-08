import 'package:flutter/material.dart';
import 'package:my_app/models/food_item.dart';

class FoodPhoto extends StatelessWidget {
  const FoodPhoto({
    super.key,
    required this.food,
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  final FoodItem food;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(food.imageUrl);
    final hasRemoteImage =
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: hasRemoteImage
            ? Image.network(
                food.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
                loadingBuilder: (context, child, loadingProgress) =>
                    loadingProgress == null ? child : _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: food.isExpiringSoon
          ? const Color(0xFFFFF1CC)
          : const Color(0xFFEAF5E8),
      child: Icon(
        food.icon,
        size: width < 64 ? 26 : 34,
        color: food.isExpiringSoon
            ? const Color(0xFFD68A00)
            : const Color(0xFF4E8D57),
      ),
    );
  }
}
