import 'package:my_app/models/food_feedback.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/models/user_preference.dart';

class RecommendationService {
  const RecommendationService();

  List<FoodItem> getRecommendations({
    required List<FoodItem> foods,
    required UserPreference preference,
    Map<String, FoodFeedback> feedbackByFoodId = const {},
    DateTime? now,
    bool requireOpenToday = true,
  }) {
    final today = now ?? DateTime.now();
    final candidates = foods.where((food) {
      final isAvailableForRecommendation =
          !requireOpenToday || food.isOpenOn(today);
      final isInBudget =
          food.price >= preference.budgetMin &&
          food.price <= preference.budgetMax;
      final isNearby =
          !food.hasDistance ||
          food.distanceMeters <= preference.distanceLimitMeters;
      final avoidsRestrictedIngredients = preference.avoidIngredients.every(
        (ingredient) => !food.ingredients.contains(ingredient),
      );

      return isAvailableForRecommendation &&
          isInBudget &&
          isNearby &&
          avoidsRestrictedIngredients;
    }).toList();

    candidates.sort((a, b) {
      final bScore = scoreFood(
        b,
        preference,
        feedback: feedbackByFoodId[b.id],
      ).totalScore;
      final aScore = scoreFood(
        a,
        preference,
        feedback: feedbackByFoodId[a.id],
      ).totalScore;
      return bScore.compareTo(aScore);
    });

    return candidates;
  }

  RecommendationScoreBreakdown scoreFood(
    FoodItem food,
    UserPreference preference, {
    FoodFeedback? feedback,
  }) {
    final tagMatches = food.tags
        .where((tag) => preference.preferredTags.contains(tag))
        .length;
    final preferenceScore = preference.preferredTags.isEmpty
        ? 0.5
        : tagMatches / preference.preferredTags.length;
    final distanceScore = food.hasDistance
        ? 1 - (food.distanceMeters / preference.distanceLimitMeters)
        : 0.5;
    final budgetCenter = (preference.budgetMin + preference.budgetMax) / 2;
    final budgetScore = 1 - ((food.price - budgetCenter).abs() / budgetCenter);
    final ecoScore = preference.wasteReductionEnabled
        ? food.ecoPriorityScore
        : 0;
    final feedbackScore = _feedbackScore(feedback);
    final totalScore =
        preferenceScore * 0.35 +
        distanceScore.clamp(0, 1) * 0.18 +
        budgetScore.clamp(0, 1) * 0.18 +
        ecoScore * 0.19 +
        feedbackScore * 0.1;

    return RecommendationScoreBreakdown(
      preferenceScore: preferenceScore.clamp(0, 1).toDouble(),
      distanceScore: distanceScore.clamp(0, 1).toDouble(),
      budgetScore: budgetScore.clamp(0, 1).toDouble(),
      ecoScore: ecoScore.clamp(0, 1).toDouble(),
      feedbackScore: feedbackScore,
      totalScore: totalScore.clamp(0, 1).toDouble(),
    );
  }

  double _feedbackScore(FoodFeedback? feedback) {
    if (feedback == null) {
      return 0.5;
    }

    var score = (feedback.rating - 1) / 4;
    if (feedback.tags.contains('會再回購')) {
      score += 0.1;
    }
    if (feedback.tags.contains('不符合偏好')) {
      score -= 0.25;
    }

    return score.clamp(0, 1).toDouble();
  }
}

class RecommendationScoreBreakdown {
  const RecommendationScoreBreakdown({
    required this.preferenceScore,
    required this.distanceScore,
    required this.budgetScore,
    required this.ecoScore,
    required this.feedbackScore,
    required this.totalScore,
  });

  final double preferenceScore;
  final double distanceScore;
  final double budgetScore;
  final double ecoScore;
  final double feedbackScore;
  final double totalScore;

  int get preferencePercent => _toPercent(preferenceScore);

  int get distancePercent => _toPercent(distanceScore);

  int get budgetPercent => _toPercent(budgetScore);

  int get ecoPercent => _toPercent(ecoScore);

  int get feedbackPercent => _toPercent(feedbackScore);

  int get totalPercent => _toPercent(totalScore);

  static int _toPercent(double value) {
    return (value * 100).round().clamp(0, 100);
  }
}
