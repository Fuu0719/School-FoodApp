import 'package:flutter/material.dart';

class MealAvatarStyle {
  const MealAvatarStyle(
    this.key,
    this.label,
    this.icon,
    this.background,
    this.foreground,
  );

  final String key;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}

const mealAvatarStyles = <MealAvatarStyle>[
  MealAvatarStyle(
    'sprout',
    '新芽',
    Icons.eco_rounded,
    Color(0xFFE2F3DF),
    Color(0xFF3D7B47),
  ),
  MealAvatarStyle(
    'rice',
    '飯糰',
    Icons.rice_bowl_rounded,
    Color(0xFFFFEDC2),
    Color(0xFF9A6500),
  ),
  MealAvatarStyle(
    'apple',
    '蘋果',
    Icons.apple_rounded,
    Color(0xFFFFDFD9),
    Color(0xFFB94737),
  ),
  MealAvatarStyle(
    'carrot',
    '胡蘿蔔',
    Icons.local_dining_rounded,
    Color(0xFFFFE3C6),
    Color(0xFFC56618),
  ),
  MealAvatarStyle(
    'leaf',
    '綠葉',
    Icons.spa_rounded,
    Color(0xFFDDF1E9),
    Color(0xFF26745B),
  ),
  MealAvatarStyle(
    'soup',
    '暖湯',
    Icons.soup_kitchen_rounded,
    Color(0xFFE5E2F7),
    Color(0xFF62559B),
  ),
  MealAvatarStyle(
    'sunny',
    '太陽蛋',
    Icons.egg_alt_rounded,
    Color(0xFFFFF0B8),
    Color(0xFFAA7200),
  ),
  MealAvatarStyle(
    'planet',
    '惜食星球',
    Icons.public_rounded,
    Color(0xFFDCECF5),
    Color(0xFF376D8A),
  ),
];

MealAvatarStyle mealAvatarStyle(String key) => mealAvatarStyles.firstWhere(
  (style) => style.key == key,
  orElse: () => mealAvatarStyles.first,
);

class MealAvatar extends StatelessWidget {
  const MealAvatar({super.key, required this.avatarKey, this.radius = 28});

  final String avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = mealAvatarStyle(avatarKey);
    return CircleAvatar(
      radius: radius,
      backgroundColor: style.background,
      child: Icon(style.icon, color: style.foreground, size: radius * 1.05),
    );
  }
}
