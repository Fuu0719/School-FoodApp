import 'package:flutter/material.dart';
import 'package:my_app/validation/phone.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/user_profile.dart';
import 'package:my_app/screens/merchant_login_screen.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/widgets/member_login_form.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.onOpenCollectionTab,
    this.onLoginComplete,
  });

  final ValueChanged<int>? onOpenCollectionTab;
  final VoidCallback? onLoginComplete;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileService _profileService = UserProfileService.instance;
  final UserActivityService _activityService = UserActivityService.instance;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_refresh);
    _activityService.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _completeProfile());
  }

  @override
  void dispose() {
    _profileService.removeListener(_refresh);
    _activityService.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileService.profile;
    final title = profile == null ? '登入' : '我的';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(
            color: Color(0xFF2E3A2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
      ),
      body: SafeArea(
        child: profile == null ? _buildLoginView() : _buildProfileView(profile),
      ),
    );
  }

  Widget _buildLoginView() {
    return MemberLoginForm(
      service: _profileService,
      onLoginComplete: () async {
        await _completeProfile();
        if (mounted &&
            _profileService.profile?.needsProfileCompletion == false) {
          widget.onLoginComplete?.call();
        }
      },
      onMerchantLogin: _goToMerchantLogin,
    );
  }

  Widget _buildProfileView(UserProfile profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProfileHeader(profile),
        const SizedBox(height: 16),
        _buildStats(),
        const SizedBox(height: 16),
        _buildHealthSummarySection(profile),
        const SizedBox(height: 16),
        _buildEcoAchievementSection(),
        const SizedBox(height: 16),
        _buildSpendingAnalysisSection(),
        const SizedBox(height: 16),
        _buildPreferenceSection(profile),
        const SizedBox(height: 16),
        _buildAccountActions(profile),
      ],
    );
  }

  Widget _buildProfileHeader(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF4E8D57),
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.phone,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatTile(
            icon: Icons.favorite_rounded,
            title: '收藏',
            value: '${_activityService.favorites.length}',
            onTap: () => widget.onOpenCollectionTab?.call(0),
          ),
          const SizedBox(width: 12),
          _buildStatTile(
            icon: Icons.history_rounded,
            title: '瀏覽紀錄',
            value: '${_activityService.history.length}',
            onTap: () => widget.onOpenCollectionTab?.call(1),
          ),
          const SizedBox(width: 12),
          _buildStatTile(
            icon: Icons.receipt_long_rounded,
            title: '點餐紀錄',
            value: '${_activityService.purchaseRecords.length}',
            onTap: () => widget.onOpenCollectionTab?.call(3),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 150,
      height: 118,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF4E8D57), size: 22),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.black38,
                        size: 18,
                      ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3A2F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummarySection(UserProfile profile) {
    if (profile.needsProfileCompletion) {
      return TextButton.icon(
        onPressed: () => _openEditSheet(profile),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('填寫身高與體重'),
      );
    }
    final target = profile.dailyNutritionTarget;
    final summary = _buildTodayHealthSummary(profile);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: Color(0xFF4E8D57),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日健康摘要',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '依身高體重與目標估算每日需求',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDailyTargetPanel(profile, target),
          const SizedBox(height: 14),
          if (summary.mealCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '尚無今日點餐紀錄，完成結帳後會自動累計熱量與營養素。',
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: summary.calorieProgress,
                minHeight: 10,
                backgroundColor: const Color(0xFFEAF5E8),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4E8D57)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildHealthMetric(
                    '熱量',
                    '${summary.calories} kcal',
                    '建議值 ${target.calories} kcal',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHealthMetric(
                    '餐點',
                    '${summary.mealCount} 份',
                    '${summary.totalWeightGrams} g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildHealthMetric(
                    '蛋白質',
                    '${summary.proteinGrams} g',
                    '',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHealthMetric('脂肪', '${summary.fatGrams} g', ''),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHealthMetric(
                    '碳水',
                    '${summary.carbsGrams} g',
                    '',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A2F),
              ),
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyTargetPanel(
    UserProfile profile,
    DailyNutritionTarget target,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${profile.healthGoal.label} / BMI ${profile.bmiLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                  ),
                ),
              ),
              Text(
                profile.bmiStatus,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E8D57),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            profile.healthGoal.description,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTargetChip('每日需求', '${target.calories} kcal'),
              _buildTargetChip('蛋白質', '${target.proteinGrams} g'),
              _buildTargetChip('脂肪', '${target.fatGrams} g'),
              _buildTargetChip('碳水', '${target.carbsGrams} g'),
              _buildTargetChip('飲水', '${target.waterMl} ml'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$title $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4E8D57),
        ),
      ),
    );
  }

  Widget _buildEcoAchievementSection() {
    final achievement = _buildEcoAchievement();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1CC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFD68A00),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '減廢成就',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activityService.isCloud
                          ? '已載入模擬訂單的惜食統計'
                          : '結帳後累積惜食點數與等級',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (achievement.points == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '尚未累積惜食點數，購買即期優惠或高減廢餐點後會自動更新。',
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.levelLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3A2F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    achievement.nextLevelHint,
                    style: const TextStyle(color: Color(0xFFD68A00)),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: achievement.progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFFFE2A7),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFD68A00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildEcoMetric(
                    '惜食點數',
                    '${achievement.points}',
                    Icons.stars_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildEcoMetric(
                    '即期份數',
                    '${achievement.savedFoodCount} 份',
                    Icons.inventory_2_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildEcoMetric(
                    '省下金額',
                    'NT\$ ${achievement.savedAmount}',
                    Icons.savings_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildEcoMissionList(achievement),
            const SizedBox(height: 12),
            _buildEcoLeaderboard(achievement),
          ],
        ],
      ),
    );
  }

  Widget _buildEcoMissionList(_EcoAchievement achievement) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每日減廢任務',
            style: TextStyle(
              color: Color(0xFF2E3A2F),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildEcoMissionRow('購買 1 份即期優惠', achievement.savedFoodCount > 0),
          _buildEcoMissionRow('累積 60 點惜食點數', achievement.points >= 60),
          _buildEcoMissionRow('省下 NT\$ 50 餐費', achievement.savedAmount >= 50),
        ],
      ),
    );
  }

  Widget _buildEcoMissionRow(String title, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: completed ? const Color(0xFF4E8D57) : Colors.black26,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: completed ? const Color(0xFF2E3A2F) : Colors.black54,
                fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoLeaderboard(_EcoAchievement achievement) {
    final ranking = _activityService.ecoLeaderboard;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE2A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '全體惜食排行榜',
            style: TextStyle(
              color: Color(0xFF2E3A2F),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (ranking.isEmpty)
            const Text('尚無排名資料', style: TextStyle(color: Colors.black54)),
          ...ranking.map((item) {
            final isMe = item.isMe;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: isMe
                        ? const Color(0xFFD68A00)
                        : const Color(0xFFEAF5E8),
                    child: Text(
                      _rankLabel(item.rank),
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFF4E8D57),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMe ? '你（${item.name}）' : item.name,
                      style: TextStyle(
                        color: isMe ? const Color(0xFFD68A00) : Colors.black87,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${item.points} 點',
                    style: const TextStyle(
                      color: Color(0xFF2E3A2F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEcoMetric(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD68A00), size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
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

  Widget _buildSpendingAnalysisSection() {
    final summary = _buildMonthlySpendingSummary();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF4E8D57),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '消費管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '依本月購買紀錄分析消費習慣',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (summary.orderCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '本月尚無購買紀錄，完成結帳後會開始分析消費金額與常買類型。',
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '本月消費',
                      style: TextStyle(
                        color: Color(0xFF2E3A2F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'NT\$ ${summary.totalAmount}',
                    style: const TextStyle(
                      color: Color(0xFF2E3A2F),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSpendingMetric(
                    '購買次數',
                    '${summary.orderCount} 筆',
                    Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSpendingMetric(
                    '餐點份數',
                    '${summary.totalQuantity} 份',
                    Icons.restaurant_menu_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSpendingMetric(
                    '平均每筆',
                    'NT\$ ${summary.averageOrderAmount}',
                    Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSpendingMetric(
                    '常買類型',
                    summary.topCategory,
                    Icons.category_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSpendingMetric(
              '即期優惠省下',
              'NT\$ ${summary.savedAmount}',
              Icons.savings_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpendingMetric(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4E8D57), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A2F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSection(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '飲食偏好',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3A2F),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openEditSheet(profile),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('編輯'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.dietaryTags
                .map((tag) => Chip(label: Text(tag)))
                .toList(),
          ),
          const SizedBox(height: 14),
          _buildPreferenceRow('預算上限', _budgetLabel(profile.budgetMax)),
          _buildPreferenceRow(
            '距離上限',
            _distanceLabel(profile.distanceLimitMeters),
          ),
          _buildPreferenceRow(
            '身高體重',
            '${_decimalLabel(profile.heightCm)} 公分 / ${_decimalLabel(profile.weightKg)} 公斤',
          ),
          _buildPreferenceRow('健康目標', profile.healthGoal.label),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.black54)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions(UserProfile profile) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openEditSheet(profile),
            icon: const Icon(Icons.manage_accounts_rounded),
            label: const Text('編輯會員資料'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _profileService.isBusy
                ? null
                : () async {
                    try {
                      await _profileService.logout();
                    } on MemberApiException catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                      }
                    }
                  },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('登出'),
          ),
        ),
      ],
    );
  }

  Future<void> _completeProfile() async {
    if (!mounted || _editing) return;
    final profile = _profileService.profile;
    if (profile != null && profile.needsProfileCompletion) {
      await _openEditSheet(profile);
    }
  }

  Future<void> _openEditSheet(UserProfile profile) async {
    if (_editing) return;
    _editing = true;
    final nameController = TextEditingController(text: profile.name);
    final emailController = TextEditingController(text: profile.email);
    final phoneController = TextEditingController(text: profile.phone);
    final heightController = TextEditingController(
      text: _decimalLabel(profile.heightCm),
    );
    final weightController = TextEditingController(
      text: _decimalLabel(profile.weightKg),
    );
    var selectedTags = {...profile.dietaryTags};
    int? budgetMax = profile.budgetMax;
    int? distanceLimit = profile.distanceLimitMeters;
    var healthGoal = profile.healthGoal;
    var saving = false;
    String? saveError;
    String? phoneError;
    final availableTags =
        FoodCatalogRepository.instance.allFoods
            .expand((food) => food.tags)
            .toSet()
            .toList()
          ..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggleTag(String tag) {
              setSheetState(() {
                selectedTags.contains(tag)
                    ? selectedTags.remove(tag)
                    : selectedTags.add(tag);
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text(
                      '編輯會員資料',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '姓名'),
                    ),
                    TextField(
                      controller: emailController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !saving,
                      onChanged: (value) => setSheetState(() {
                        phoneError = validateOptionalPhone(value);
                      }),
                      decoration: InputDecoration(
                        labelText: '電話（選填）',
                        errorText: phoneError,
                      ),
                    ),
                    TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '身高（公分）'),
                    ),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '體重（公斤）'),
                    ),
                    DropdownButtonFormField<HealthGoal>(
                      initialValue: healthGoal,
                      decoration: const InputDecoration(labelText: '健康目標'),
                      items: HealthGoal.values
                          .map(
                            (goal) => DropdownMenuItem<HealthGoal>(
                              value: goal,
                              child: Text(goal.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setSheetState(() {
                          healthGoal = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '偏好標籤',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTags
                          .map(
                            (tag) => FilterChip(
                              label: Text(tag),
                              selected: selectedTags.contains(tag),
                              onSelected: (_) => toggleTag(tag),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: budgetMax,
                      decoration: const InputDecoration(labelText: '預算上限'),
                      items:
                          <int?>{
                                80,
                                120,
                                150,
                                200,
                                300,
                                null,
                                profile.budgetMax,
                              }
                              .map(
                                (value) => DropdownMenuItem<int?>(
                                  value: value,
                                  child: Text(
                                    value == null ? '不限' : '$value 元',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          budgetMax = value;
                        });
                      },
                    ),
                    DropdownButtonFormField<int?>(
                      initialValue: distanceLimit,
                      decoration: const InputDecoration(labelText: '距離上限'),
                      items:
                          <int?>{
                                500,
                                800,
                                1000,
                                1500,
                                null,
                                profile.distanceLimitMeters,
                              }
                              .map(
                                (value) => DropdownMenuItem<int?>(
                                  value: value,
                                  child: Text(
                                    value == null ? '不限' : '$value 公尺',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          distanceLimit = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    if (saveError != null)
                      Text(
                        saveError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final validation = validateOptionalPhone(
                                phoneController.text,
                              );
                              if (validation != null) {
                                setSheetState(() => phoneError = validation);
                                return;
                              }
                              setSheetState(() {
                                saving = true;
                                saveError = null;
                              });
                              try {
                                await _profileService.updateProfile(
                                  profile.copyWith(
                                    name: nameController.text.trim(),
                                    email: emailController.text.trim(),
                                    phone: normalizeOptionalPhone(
                                      phoneController.text,
                                    )!,
                                    dietaryTags: selectedTags.toList(),
                                    budgetMax: budgetMax,
                                    distanceLimitMeters: distanceLimit,
                                    heightCm: _parsePositiveDouble(
                                      heightController.text,
                                      '身高',
                                    ),
                                    weightKg: _parsePositiveDouble(
                                      weightController.text,
                                      '體重',
                                    ),
                                    healthGoal: healthGoal,
                                    clearBudgetMax: budgetMax == null,
                                    clearDistanceLimit: distanceLimit == null,
                                  ),
                                );
                                if (context.mounted) Navigator.pop(context);
                              } on MemberApiException catch (error) {
                                if (context.mounted) {
                                  setSheetState(
                                    () => saveError = error.message,
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      child: Text(saving ? '儲存中' : '儲存'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    _editing = false;
    // Controllers belong to the sheet and are released after its exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    heightController.dispose();
    weightController.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _goToMerchantLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MerchantLoginScreen()),
    );
  }

  String _budgetLabel(int? budgetMax) {
    return budgetMax == null ? '不限' : '$budgetMax 元';
  }

  String _rankLabel(int rank) {
    if (rank <= 3) return '$rank';
    if (rank < 10) return '$rank';
    final base = rank < 100 ? (rank ~/ 10) * 10 : (rank ~/ 100) * 100;
    return '$base+';
  }

  String _distanceLabel(int? distanceLimitMeters) {
    return distanceLimitMeters == null ? '不限' : '$distanceLimitMeters 公尺';
  }

  _HealthSummary _buildTodayHealthSummary(UserProfile profile) {
    final today = DateTime.now();
    final target = profile.dailyNutritionTarget;
    var mealCount = 0;
    var calories = 0;
    var totalWeightGrams = 0;
    var proteinGrams = 0;
    var fatGrams = 0;
    var carbsGrams = 0;

    for (final record in _activityService.purchaseRecords) {
      if (!_isSameDate(record.purchasedAt, today)) {
        continue;
      }

      for (final item in record.items) {
        mealCount += item.quantity;
        calories += item.food.calories * item.quantity;
        totalWeightGrams += item.food.weightGrams * item.quantity;
        proteinGrams += item.food.proteinGrams * item.quantity;
        fatGrams += item.food.fatGrams * item.quantity;
        carbsGrams += item.food.carbsGrams * item.quantity;
      }
    }

    return _HealthSummary(
      mealCount: mealCount,
      calories: calories,
      totalWeightGrams: totalWeightGrams,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbsGrams: carbsGrams,
      dailyCalorieTarget: target.calories,
    );
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  _EcoAchievement _buildEcoAchievement() {
    return _EcoAchievement(
      points: _activityService.ecoPoints,
      savedFoodCount: _activityService.savedFoodCount,
      savedAmount: _activityService.savedAmount,
    );
  }

  _SpendingSummary _buildMonthlySpendingSummary() {
    final now = DateTime.now();
    final categoryCounts = <String, int>{};
    var orderCount = 0;
    var totalQuantity = 0;
    var totalAmount = 0;
    var savedAmount = 0;

    for (final record in _activityService.purchaseRecords) {
      if (!_isSameMonth(record.purchasedAt, now)) {
        continue;
      }

      orderCount += 1;
      totalQuantity += record.totalQuantity;
      totalAmount += record.totalPrice;

      for (final item in record.items) {
        categoryCounts.update(
          item.food.category,
          (count) => count + item.quantity,
          ifAbsent: () => item.quantity,
        );

        final originalPrice = item.food.originalPrice;
        if (item.food.isExpiringSoon && originalPrice != null) {
          savedAmount += (originalPrice - item.food.price) * item.quantity;
        }
      }
    }

    final topCategory = categoryCounts.entries.isEmpty
        ? '尚無資料'
        : (categoryCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

    return _SpendingSummary(
      orderCount: orderCount,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
      savedAmount: savedAmount,
      topCategory: topCategory,
    );
  }

  bool _isSameMonth(DateTime first, DateTime second) {
    return first.year == second.year && first.month == second.month;
  }

  double _parsePositiveDouble(String text, String label) {
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite || value <= 0) {
      throw MemberApiException('請輸入有效的$label');
    }

    return value;
  }

  String _decimalLabel(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _HealthSummary {
  const _HealthSummary({
    required this.mealCount,
    required this.calories,
    required this.totalWeightGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    required this.dailyCalorieTarget,
  });

  final int mealCount;
  final int calories;
  final int totalWeightGrams;
  final int proteinGrams;
  final int fatGrams;
  final int carbsGrams;
  final int dailyCalorieTarget;

  double get calorieProgress {
    if (dailyCalorieTarget == 0) {
      return 0;
    }

    return (calories / dailyCalorieTarget).clamp(0, 1).toDouble();
  }
}

class _EcoAchievement {
  const _EcoAchievement({
    required this.points,
    required this.savedFoodCount,
    required this.savedAmount,
  });

  final int points;
  final int savedFoodCount;
  final int savedAmount;

  int get level {
    if (points >= 400) {
      return 4;
    }

    if (points >= 180) {
      return 3;
    }

    if (points >= 60) {
      return 2;
    }

    return 1;
  }

  String get levelName {
    return switch (level) {
      4 => '永續選餐家',
      3 => '減廢達人',
      2 => '惜食行動者',
      _ => '食光新手',
    };
  }

  String get levelLabel => 'Lv.$level $levelName';

  int get currentThreshold {
    return switch (level) {
      4 => 400,
      3 => 180,
      2 => 60,
      _ => 0,
    };
  }

  int? get nextThreshold {
    return switch (level) {
      1 => 60,
      2 => 180,
      3 => 400,
      _ => null,
    };
  }

  String get nextLevelHint {
    final next = nextThreshold;
    if (next == null) {
      return '已達目前最高等級，持續累積惜食成果';
    }

    return '距離下一級還差 ${next - points} 點';
  }

  double get progress {
    final next = nextThreshold;
    if (next == null) {
      return 1;
    }

    final span = next - currentThreshold;
    if (span <= 0) {
      return 1;
    }

    return ((points - currentThreshold) / span).clamp(0, 1).toDouble();
  }
}

class _SpendingSummary {
  const _SpendingSummary({
    required this.orderCount,
    required this.totalQuantity,
    required this.totalAmount,
    required this.savedAmount,
    required this.topCategory,
  });

  final int orderCount;
  final int totalQuantity;
  final int totalAmount;
  final int savedAmount;
  final String topCategory;

  int get averageOrderAmount {
    if (orderCount == 0) {
      return 0;
    }

    return (totalAmount / orderCount).round();
  }
}
