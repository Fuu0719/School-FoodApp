import 'dart:convert';

import 'package:flutter/material.dart';

class MealAvatar extends StatelessWidget {
  const MealAvatar({super.key, required this.avatarKey, this.radius = 28});

  final String avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (avatarKey.startsWith('data:image/')) {
      try {
        image = MemoryImage(base64Decode(avatarKey.split(',').last));
      } on FormatException {
        image = null;
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE2F3DF),
      backgroundImage: image,
      child: image == null
          ? Icon(
              Icons.person_rounded,
              color: const Color(0xFF3D7B47),
              size: radius * 1.15,
            )
          : null,
    );
  }
}
