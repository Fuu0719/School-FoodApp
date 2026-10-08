import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/screens/food_detail_screen.dart';
import 'package:my_app/services/food_search_service.dart';
import 'package:my_app/services/food_wheel_service.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/widgets/food_card.dart';

class WheelScreen extends StatefulWidget {
  const WheelScreen({super.key});

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen>
    with SingleTickerProviderStateMixin {
  final FoodWheelService _wheelService = const FoodWheelService();
  final UserActivityService _activityService = UserActivityService.instance;
  late final AnimationController _animationController;
  late Animation<double> _turns;
  double _rotationTurns = 0;
  bool _isSpinning = false;
  bool _showCelebration = false;

  FoodSearchFilters _filters = const FoodSearchFilters();
  FoodItem? _selectedFood;
  String? _selectedCategory;

  List<FoodItem> get _candidates {
    return _wheelService.getCandidates(
      foods: FoodCatalogRepository.instance.allFoods,
      filters: _filters,
    );
  }

  List<String> get _categories {
    return FoodCatalogRepository.instance.allFoods
        .map((food) => food.category)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _tags {
    return FoodCatalogRepository.instance.allFoods
        .expand((food) => food.tags)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _turns = const AlwaysStoppedAnimation(0);
    _activityService.addListener(_refresh);
  }

  @override
  void dispose() {
    _activityService.removeListener(_refresh);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '食物轉盤',
          style: TextStyle(
            color: Color(0xFF2E3A2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildIntroCard(candidates.length),
          const SizedBox(height: 18),
          _buildFilterPanel(),
          const SizedBox(height: 18),
          _buildWheelResult(candidates),
          const SizedBox(height: 18),
          _buildCandidatePreview(candidates),
        ],
      ),
    );
  }

  Widget _buildIntroCard(int candidateCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2F3E30),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先決定類型，再挑餐點',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '把選擇障礙縮小成一個餐點類型',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '目前候選餐點：$candidateCount 項，轉盤會先抽出類型，再從該類型挑出一餐。',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            '轉盤條件',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('只看即期優惠'),
                selected: _filters.expiringOnly,
                onSelected: (selected) =>
                    _updateFilters(_filters.copyWith(expiringOnly: selected)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildChipSection(
            title: '餐點類型',
            children: _categories
                .map(
                  (category) => FilterChip(
                    label: Text(category),
                    selected: _filters.categories.contains(category),
                    onSelected: (_) => _toggleCategory(category),
                  ),
                )
                .toList(),
          ),
          _buildChipSection(
            title: '偏好標籤',
            children: _tags
                .map(
                  (tag) => FilterChip(
                    label: Text(tag),
                    selected: _filters.tags.contains(tag),
                    onSelected: (_) => _toggleTag(tag),
                  ),
                )
                .toList(),
          ),
          Row(
            children: [
              Expanded(
                child: _buildOptionMenu(
                  label: '預算',
                  value: _filters.maxPrice,
                  options: const [80, 120, 150, 200, 300],
                  suffix: '元內',
                  onChanged: (price) => _updateFilters(
                    _filters.copyWith(
                      maxPrice: price,
                      clearMaxPrice: price == null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionMenu(
                  label: '距離',
                  value: _filters.maxDistanceMeters,
                  options: const [500, 800, 1000, 1500],
                  suffix: '公尺內',
                  onChanged: (distance) => _updateFilters(
                    _filters.copyWith(
                      maxDistanceMeters: distance,
                      clearMaxDistance: distance == null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  Widget _buildOptionMenu({
    required String label,
    required int? value,
    required List<int> options,
    required String suffix,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: <int?>[...options, null]
          .map(
            (option) => DropdownMenuItem<int?>(
              value: option,
              child: Text(option == null ? '不限' : '$option $suffix'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildWheelResult(List<FoodItem> candidates) {
    final categoryCandidates = _selectedCategory == null
        ? const <FoodItem>[]
        : _wheelService.getCandidatesByCategory(candidates, _selectedCategory!);
    final wheelCategories = _wheelService.getCandidateCategories(candidates);
    final visualCategories = wheelCategories.isEmpty
        ? _categories.take(6).toList()
        : wheelCategories;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE3A3)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 202,
            height: 214,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (_showCelebration)
                  ...List.generate(10, (index) {
                    final angle = math.pi * 2 * index / 10;
                    return Positioned(
                      left: 94 + math.cos(angle) * 92,
                      top: 100 + math.sin(angle) * 92,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 420 + index * 22),
                        builder: (context, value, child) => Transform.scale(
                          scale: 1 - value * 0.35,
                          child: Opacity(opacity: 1 - value, child: child),
                        ),
                        child: Icon(
                          index.isEven ? Icons.eco_rounded : Icons.star_rounded,
                          size: 14,
                          color: index.isEven
                              ? const Color(0xFF4E8D57)
                              : const Color(0xFFFFA000),
                        ),
                      ),
                    );
                  }),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: RotationTransition(
                    turns: _turns,
                    child: CustomPaint(
                      size: const Size(176, 176),
                      painter: _WheelPainter(
                        categories: visualCategories,
                        selectedCategory: _selectedCategory,
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) => Transform.rotate(
                    angle: _isSpinning
                        ? math.sin(_animationController.value * math.pi * 32) *
                              0.08
                        : 0,
                    child: child,
                  ),
                  child: const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 42,
                    color: Color(0xFFD68A00),
                  ),
                ),
                Positioned(
                  top: 84,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFE3A3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.casino_rounded,
                      color: Color(0xFF2F3E30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '類型轉盤 ${visualCategories.length} 格',
            style: const TextStyle(
              color: Color(0xFFD68A00),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _selectedCategory == null
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(_selectedCategory),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE3A3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '今天吃：$_selectedCategory',
                      style: const TextStyle(
                        color: Color(0xFF2F3E30),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          Text(
            _selectedFood == null ? '按下轉盤，先幫你選類型' : _selectedFood!.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFood == null
                ? '系統會用目前條件排除不符合的餐點，再用類型轉盤縮小選擇範圍。'
                : '${_selectedFood!.storeName} / ${_selectedFood!.priceLabel} / ${_selectedFood!.distanceLabel}\n同類型候選 ${categoryCandidates.length} 項',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: candidates.isEmpty || _isSpinning
                      ? null
                      : () => _spin(candidates),
                  icon: Icon(
                    _isSpinning
                        ? Icons.autorenew_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(_isSpinning ? '轉動中...' : '轉出類型'),
                ),
              ),
              if (_selectedFood != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _goToFoodDetail(_selectedFood!),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('看詳情'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatePreview(List<FoodItem> candidates) {
    if (candidates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            '請先設定轉盤條件，系統會列出符合條件的候選餐點。',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final visibleCandidates = _selectedCategory == null
        ? candidates
        : _wheelService.getCandidatesByCategory(candidates, _selectedCategory!);
    final title = _selectedCategory == null
        ? '候選餐點'
        : '$_selectedCategory 候選餐點';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3A2F),
          ),
        ),
        const SizedBox(height: 12),
        ...visibleCandidates
            .take(3)
            .map(
              (food) => FoodCard(
                food: food,
                showDistance: true,
                variant: food.isExpiringSoon
                    ? FoodCardVariant.expiring
                    : FoodCardVariant.recommendation,
                isFavorite: _activityService.isFavorite(food.id),
                favoriteBusy: _activityService.isFavoriteBusy(food.id),
                onTap: () => _goToFoodDetail(food),
                onFavoritePressed: () => _activityService.toggleFavorite(food),
              ),
            ),
        if (visibleCandidates.length > 3) ...[
          const SizedBox(height: 4),
          _buildAllCandidatesDropdown(visibleCandidates),
        ],
      ],
    );
  }

  Widget _buildAllCandidatesDropdown(List<FoodItem> candidates) {
    final hiddenCandidates = candidates.skip(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EDE2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          iconColor: const Color(0xFF4E8D57),
          collapsedIconColor: const Color(0xFF4E8D57),
          title: Text(
            '查看全部候選餐點（${candidates.length} 項）',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          subtitle: Text(
            '另有 ${hiddenCandidates.length} 項符合目前轉盤條件',
            style: const TextStyle(color: Colors.black54),
          ),
          children: hiddenCandidates
              .map(
                (food) => FoodCard(
                  food: food,
                  showDistance: true,
                  variant: food.isExpiringSoon
                      ? FoodCardVariant.expiring
                      : FoodCardVariant.recommendation,
                  isFavorite: _activityService.isFavorite(food.id),
                  favoriteBusy: _activityService.isFavoriteBusy(food.id),
                  onTap: () => _goToFoodDetail(food),
                  onFavoritePressed: () =>
                      _activityService.toggleFavorite(food),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _spin(List<FoodItem> candidates) async {
    if (_isSpinning) return;
    final result = _wheelService.spinByCategory(candidates: candidates);
    if (result == null) return;
    final categories = _wheelService.getCandidateCategories(candidates);
    final selectedIndex = categories.indexOf(result.category);
    if (selectedIndex < 0) return;

    final random = math.Random();
    final segmentPosition = 0.18 + random.nextDouble() * 0.64;
    final targetFraction =
        (1 - ((selectedIndex + segmentPosition) / categories.length)) % 1;
    final targetTurns =
        _rotationTurns.floorToDouble() + 4 + random.nextInt(3) + targetFraction;

    setState(() {
      _selectedCategory = null;
      _selectedFood = null;
      _showCelebration = false;
      _isSpinning = true;
      _turns = Tween<double>(begin: _rotationTurns, end: targetTurns).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutQuart,
        ),
      );
    });

    await _animationController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _rotationTurns = targetTurns;
      _turns = AlwaysStoppedAnimation(_rotationTurns);
      _selectedCategory = result.category;
      _selectedFood = result.food;
      _isSpinning = false;
      _showCelebration = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _updateFilters(FoodSearchFilters filters) {
    setState(() {
      _filters = filters;
      _selectedFood = null;
      _selectedCategory = null;
    });
  }

  void _toggleTag(String tag) {
    final tags = {..._filters.tags};
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    _updateFilters(_filters.copyWith(tags: tags));
  }

  void _toggleCategory(String category) {
    final categories = {..._filters.categories};
    categories.contains(category)
        ? categories.remove(category)
        : categories.add(category);
    _updateFilters(_filters.copyWith(categories: categories));
  }

  void _goToFoodDetail(FoodItem food) {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FoodDetailScreen(food: food)),
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({
    required this.categories,
    required this.selectedCategory,
  });

  final List<String> categories;
  final String? selectedCategory;

  static const List<Color> _segmentColors = [
    Color(0xFFFFD86B),
    Color(0xFF9CCF8E),
    Color(0xFFFFA36C),
    Color(0xFF8FC9E8),
    Color(0xFFEFB3C6),
    Color(0xFFC8B6FF),
    Color(0xFFFFE3A3),
    Color(0xFFA8DADC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final labels = categories.isEmpty
        ? const ['推薦']
        : categories.take(8).toList();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = math.pi * 2 / labels.length;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var index = 0; index < labels.length; index += 1) {
      final label = labels[index];
      final startAngle = -math.pi / 2 + index * sweep;
      final paint = Paint()
        ..color = selectedCategory == label
            ? const Color(0xFFD68A00)
            : _segmentColors[index % _segmentColors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweep, true, paint);
      canvas.drawArc(rect, startAngle, sweep, true, borderPaint);
      _paintLabel(canvas, center, radius, startAngle + sweep / 2, label);
    }

    canvas.drawCircle(center, radius, borderPaint);
  }

  void _paintLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String label,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: selectedCategory == label
              ? Colors.white
              : const Color(0xFF2F3E30),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 0.7);

    final offset = Offset(
      center.dx + math.cos(angle) * radius * 0.56 - textPainter.width / 2,
      center.dy + math.sin(angle) * radius * 0.56 - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.categories.join(',') != categories.join(',');
  }
}
