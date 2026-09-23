import 'package:flutter/material.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/food_feedback.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/models/user_preference.dart';
import 'package:my_app/screens/food_detail_screen.dart';
import 'package:my_app/services/recommendation_service.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/food_card.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final RecommendationService _recommendationService =
      const RecommendationService();
  final UserActivityService _activityService = UserActivityService.instance;
  final UserProfileService _profileService = UserProfileService.instance;
  late List<FoodItem> recommendedFoods;

  @override
  void initState() {
    super.initState();
    recommendedFoods = _buildRecommendations();
    _activityService.addListener(_refreshRecommendations);
    _profileService.addListener(_refreshRecommendations);
  }

  @override
  void dispose() {
    _activityService.removeListener(_refreshRecommendations);
    _profileService.removeListener(_refreshRecommendations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preference = _currentPreference;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: const Color(0xFFF7F9F4),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                '推薦餐點',
                style: TextStyle(
                  color: Color(0xFF2E3A2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
            )
          : null,
      body: Column(
        children: [
          _buildTopSummary(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: recommendedFoods.length,
              itemBuilder: (context, index) {
                final food = recommendedFoods[index];
                final score = _recommendationService.scoreFood(
                  food,
                  preference,
                  feedback: _feedbackByFoodId[food.id],
                );

                return Column(
                  children: [
                    FoodCard(
                      food: food,
                      showDistance: true,
                      isFavorite: _activityService.isFavorite(food.id),
                      favoriteBusy: _activityService.isFavoriteBusy(food.id),
                      onTap: () => _goToFoodDetail(food),
                      onFavoritePressed: () =>
                          _activityService.toggleFavorite(food),
                    ),
                    _buildScoreBreakdown(food, score),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7DBA84), Color(0xFF4E8D57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日推薦結果',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '依照你的偏好、預算與距離，\n幫你挑出最適合的餐點',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _summaryText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRuleChip('偏好 35%'),
              _buildRuleChip('距離 18%'),
              _buildRuleChip('預算 18%'),
              _buildRuleChip('減廢 19%'),
              _buildRuleChip('回饋 10%'),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openRecommendationRulesSheet,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.rule_rounded, size: 18),
            label: const Text('查看推薦原則'),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown(
    FoodItem food,
    RecommendationScoreBreakdown score,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EDE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                size: 18,
                color: Color(0xFF4E8D57),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '推薦分數 ${score.totalPercent} 分',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                  ),
                ),
              ),
              Text(
                _matchedTagsText(food),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScoreChip('偏好', score.preferencePercent),
              _buildScoreChip('距離', score.distancePercent),
              _buildScoreChip('預算', score.budgetPercent),
              _buildScoreChip('減廢', score.ecoPercent),
              _buildScoreChip('回饋', score.feedbackPercent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(String title, int percent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$title $percent%',
        style: const TextStyle(
          color: Color(0xFF4E8D57),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<FoodItem> _buildRecommendations() {
    return _recommendationService.getRecommendations(
      foods: FoodCatalogRepository.instance.allFoods,
      preference: _currentPreference,
      feedbackByFoodId: _feedbackByFoodId,
    );
  }

  Map<String, FoodFeedback> get _feedbackByFoodId {
    return {
      for (final feedback in _activityService.feedbacks)
        feedback.foodId: feedback,
    };
  }

  UserPreference get _currentPreference {
    final profile = _profileService.profile;

    if (profile == null) {
      return UserPreference.defaultPreference;
    }

    return UserPreference(
      dietaryPreferences: profile.dietaryTags,
      budgetMin: 0,
      budgetMax: profile.budgetMax ?? 999999,
      distanceLimitMeters: profile.distanceLimitMeters ?? 999999,
      preferredTags: profile.dietaryTags,
      avoidIngredients: const [],
      wasteReductionEnabled: true,
    );
  }

  String get _summaryText {
    final profile = _profileService.profile;
    final preference = _currentPreference;
    final tags = preference.preferredTags.isEmpty
        ? '未設定偏好'
        : preference.preferredTags.take(3).join(' / ');
    final budget = profile?.budgetMax == null
        ? '預算不限'
        : '預算 ${profile!.budgetMax} 元內';
    final distance = profile?.distanceLimitMeters == null
        ? '距離不限'
        : '距離 ${profile!.distanceLimitMeters} 公尺內';

    return '推薦依據：$tags / $budget / $distance';
  }

  String _matchedTagsText(FoodItem food) {
    final matchedTags = food.tags
        .where((tag) => _currentPreference.preferredTags.contains(tag))
        .take(2)
        .toList();

    if (matchedTags.isEmpty) {
      return '探索餐點';
    }

    return matchedTags.join(' / ');
  }

  void _openRecommendationRulesSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '推薦原則',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRuleRow('先排除今日未營業、超出預算或距離的餐點'),
                _buildRuleRow('偏好標籤符合度佔 35%，例如高蛋白、低脂、清爽'),
                _buildRuleRow('距離與預算各佔 18%，越接近設定條件分數越高'),
                _buildRuleRow('減廢分數佔 19%，鼓勵選擇即期或高利用率餐點'),
                _buildRuleRow('餐點評分與回饋標籤佔 10%，會影響後續排序'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRuleRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4E8D57),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  void _goToFoodDetail(FoodItem food) {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FoodDetailScreen(food: food)),
    );
  }

  void _refreshRecommendations() {
    if (mounted) {
      setState(() {
        recommendedFoods = _buildRecommendations();
      });
    }
  }
}
