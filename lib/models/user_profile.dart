class UserProfile {
  const UserProfile({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.dietaryTags,
    required this.budgetMax,
    required this.distanceLimitMeters,
    required this.heightCm,
    required this.weightKg,
    required this.healthGoal,
  });

  final String? id;
  final String name;
  final String email;
  final String phone;
  final List<String> dietaryTags;
  final int? budgetMax;
  final int? distanceLimitMeters;
  final double? heightCm;
  final double? weightKg;
  bool get needsProfileCompletion => heightCm == null || weightKg == null;
  final HealthGoal healthGoal;

  double get bmi {
    final heightMeters = (heightCm ?? 0) / 100;
    if (heightMeters <= 0) {
      return 0;
    }

    return (weightKg ?? 0) / (heightMeters * heightMeters);
  }

  String get bmiLabel =>
      needsProfileCompletion ? '未填寫' : bmi.toStringAsFixed(1);

  String get bmiStatus {
    if (needsProfileCompletion) return '未填寫';
    if (bmi < 18.5) {
      return '偏瘦';
    }

    if (bmi < 24) {
      return '標準';
    }

    if (bmi < 27) {
      return '過重';
    }

    return '偏高';
  }

  DailyNutritionTarget get dailyNutritionTarget {
    if (needsProfileCompletion) {
      return const DailyNutritionTarget(
        calories: 0,
        proteinGrams: 0,
        fatGrams: 0,
        carbsGrams: 0,
        waterMl: 0,
      );
    }
    final weightKg = this.weightKg!;
    final baseCalories = switch (healthGoal) {
      HealthGoal.muscleGain => weightKg * 34,
      HealthGoal.fatLoss => weightKg * 24,
      HealthGoal.maintain => weightKg * 30,
    };
    final bmiAdjustment = switch (healthGoal) {
      HealthGoal.muscleGain when bmi < 18.5 => 150,
      HealthGoal.fatLoss when bmi >= 24 => -100,
      _ => 0,
    };
    final calories = (baseCalories + bmiAdjustment).round().clamp(1200, 3200);
    final proteinGrams = switch (healthGoal) {
      HealthGoal.muscleGain => (weightKg * 1.8).round(),
      HealthGoal.fatLoss => (weightKg * 2.0).round(),
      HealthGoal.maintain => (weightKg * 1.5).round(),
    };
    final fatGrams = switch (healthGoal) {
      HealthGoal.muscleGain => (weightKg * 0.9).round(),
      HealthGoal.fatLoss => (weightKg * 0.8).round(),
      HealthGoal.maintain => (weightKg * 0.8).round(),
    };
    final carbCalories = calories - proteinGrams * 4 - fatGrams * 9;
    final carbsGrams = (carbCalories / 4).round().clamp(80, 520);
    final waterMl = (weightKg * 35).round();

    return DailyNutritionTarget(
      calories: calories,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbsGrams: carbsGrams,
      waterMl: waterMl,
    );
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    List<String>? dietaryTags,
    int? budgetMax,
    int? distanceLimitMeters,
    double? heightCm,
    double? weightKg,
    HealthGoal? healthGoal,
    bool clearBudgetMax = false,
    bool clearDistanceLimit = false,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      budgetMax: clearBudgetMax ? null : budgetMax ?? this.budgetMax,
      distanceLimitMeters: clearDistanceLimit
          ? null
          : distanceLimitMeters ?? this.distanceLimitMeters,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      healthGoal: healthGoal ?? this.healthGoal,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'dietaryTags': dietaryTags,
      'budgetMax': budgetMax,
      'distanceLimitMeters': distanceLimitMeters,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'healthGoal': healthGoal.name,
    };
  }

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? demo.name,
      email: json['email'] as String? ?? demo.email,
      phone: json['phone'] as String? ?? demo.phone,
      dietaryTags:
          (json['dietaryTags'] as List?)?.whereType<String>().toList() ??
          demo.dietaryTags,
      budgetMax: json['budgetMax'] as int?,
      distanceLimitMeters: json['distanceLimitMeters'] as int?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      healthGoal: HealthGoal.fromName(json['healthGoal'] as String?),
    );
  }

  static const demo = UserProfile(
    name: '測試使用者',
    email: 'demo@foodapp.local',
    phone: '0912-345-678',
    dietaryTags: ['高蛋白', '低脂', '均衡'],
    budgetMax: 150,
    distanceLimitMeters: 1000,
    heightCm: 170,
    weightKg: 65,
    healthGoal: HealthGoal.maintain,
  );
}

enum HealthGoal {
  maintain,
  muscleGain,
  fatLoss;

  String get label {
    return switch (this) {
      HealthGoal.maintain => '維持健康',
      HealthGoal.muscleGain => '增肌',
      HealthGoal.fatLoss => '減脂',
    };
  }

  String get description {
    return switch (this) {
      HealthGoal.maintain => '穩定攝取，維持日常體態',
      HealthGoal.muscleGain => '提高熱量與蛋白質，支援肌肉成長',
      HealthGoal.fatLoss => '控制熱量，保留較高蛋白質',
    };
  }

  static HealthGoal fromName(String? name) {
    for (final goal in HealthGoal.values) {
      if (goal.name == name) {
        return goal;
      }
    }

    return HealthGoal.maintain;
  }
}

class DailyNutritionTarget {
  const DailyNutritionTarget({
    required this.calories,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    required this.waterMl,
  });

  final int calories;
  final int proteinGrams;
  final int fatGrams;
  final int carbsGrams;
  final int waterMl;
}
