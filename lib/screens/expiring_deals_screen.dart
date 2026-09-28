import 'package:flutter/material.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/convenience_store.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/screens/food_detail_screen.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/food_card.dart';

class ExpiringDealsScreen extends StatefulWidget {
  const ExpiringDealsScreen({super.key});

  @override
  State<ExpiringDealsScreen> createState() => _ExpiringDealsScreenState();
}

class _ExpiringDealsScreenState extends State<ExpiringDealsScreen> {
  static const int _fallbackDistanceLimitMeters = 1500;

  final UserProfileService _profileService = UserProfileService.instance;
  ConvenienceBrand? _selectedBrand;

  int? get _effectiveDistanceLimitMeters {
    final profile = _profileService.profile;
    return profile == null
        ? _fallbackDistanceLimitMeters
        : profile.distanceLimitMeters;
  }

  List<ConvenienceStore> get _stores {
    return FoodCatalogRepository.instance
        .convenienceStoresByBrand(
          _selectedBrand,
          maxDistanceMeters: _effectiveDistanceLimitMeters,
        )
        .where(
          (store) => FoodCatalogRepository.instance
              .expiringFoodsByStore(store.id)
              .isNotEmpty,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_refresh);
  }

  @override
  void dispose() {
    _profileService.removeListener(_refresh);
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
          '即期優惠',
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
            _buildSummary(),
            const SizedBox(height: 14),
            _buildBrandFilters(),
            const SizedBox(height: 14),
            ..._stores.map((store) => _buildStoreTile(context, store)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final totalFoods = FoodCatalogRepository.instance
        .expiringFoodsByBrand(
          _selectedBrand,
          maxDistanceMeters: _effectiveDistanceLimitMeters,
        )
        .length;
    final totalStores = _stores.length;

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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1CC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFFD68A00),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '依距離上限 $_effectiveDistanceLimitMeters 公尺',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E3A2F),
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '模擬位置：桃園銘傳大學，$totalStores 間超商，$totalFoods 項即期商品',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: _selectedBrand == null,
          onSelected: (_) => _selectBrand(null),
        ),
        ChoiceChip(
          label: const Text('全家'),
          selected: _selectedBrand == ConvenienceBrand.familyMart,
          onSelected: (_) => _selectBrand(ConvenienceBrand.familyMart),
        ),
        ChoiceChip(
          label: const Text('7-11'),
          selected: _selectedBrand == ConvenienceBrand.sevenEleven,
          onSelected: (_) => _selectBrand(ConvenienceBrand.sevenEleven),
        ),
      ],
    );
  }

  Widget _buildStoreTile(BuildContext context, ConvenienceStore store) {
    final foods = FoodCatalogRepository.instance.expiringFoodsByStore(store.id);
    final riceBallCount = _countCategory(foods, '飯糰');
    final otherCount = foods
        .where((food) => food.category != '飯糰')
        .fold<int>(0, (sum, food) => sum + food.stockCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpiringStoreScreen(store: store),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              _buildBrandLogo(store.brand),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${store.distanceLabel} / 步行約 ${store.walkingMinutes} 分',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStoreStat('飯糰剩餘 $riceBallCount 個'),
                        _buildStoreStat('其他即期品 $otherCount 件'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreStat(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1CC),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD68A00),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBrandLogo(ConvenienceBrand brand) {
    final isFamily = brand == ConvenienceBrand.familyMart;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: isFamily ? const Color(0xFFE6F4FF) : const Color(0xFFFFF1CC),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        isFamily ? '全家' : '7-11',
        style: TextStyle(
          color: isFamily ? const Color(0xFF1677B7) : const Color(0xFFD86100),
          fontWeight: FontWeight.bold,
          fontSize: isFamily ? 18 : 17,
        ),
      ),
    );
  }

  int _countCategory(List<FoodItem> foods, String category) {
    return foods
        .where((food) => food.category == category)
        .fold<int>(0, (sum, food) => sum + food.stockCount);
  }

  void _selectBrand(ConvenienceBrand? brand) {
    setState(() {
      _selectedBrand = brand;
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}

class ExpiringStoreScreen extends StatefulWidget {
  const ExpiringStoreScreen({super.key, required this.store});

  final ConvenienceStore store;

  @override
  State<ExpiringStoreScreen> createState() => _ExpiringStoreScreenState();
}

class _ExpiringStoreScreenState extends State<ExpiringStoreScreen> {
  final UserActivityService _activityService = UserActivityService.instance;
  String _selectedCategory = '全部';

  List<FoodItem> get _foods {
    final foods = FoodCatalogRepository.instance.expiringFoodsByStore(
      widget.store.id,
    );
    if (_selectedCategory == '全部') {
      return foods;
    }

    return foods.where((food) => food.category == _selectedCategory).toList();
  }

  List<String> get _categories {
    final categories =
        FoodCatalogRepository.instance
            .expiringFoodsByStore(widget.store.id)
            .map((food) => food.category)
            .toSet()
            .toList()
          ..sort();
    return ['全部', ...categories];
  }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '門市即期商品',
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
            _buildStoreHeader(),
            const SizedBox(height: 14),
            _buildCategoryFilters(),
            const SizedBox(height: 14),
            if (_foods.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    '此分類目前沒有即期商品',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ..._foods.map(
                (food) => FoodCard(
                  food: food,
                  variant: FoodCardVariant.expiring,
                  showDistance: true,
                  isFavorite: _activityService.isFavorite(food.id),
                  favoriteBusy: _activityService.isFavoriteBusy(food.id),
                  onTap: () => _goToFoodDetail(food),
                  onFavoritePressed: () =>
                      _activityService.toggleFavorite(food),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader() {
    final foods = FoodCatalogRepository.instance.expiringFoodsByStore(
      widget.store.id,
    );
    final stockTotal = foods.fold<int>(0, (sum, food) => sum + food.stockCount);

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
          Row(
            children: [
              _buildBrandLogo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.store.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.store.distanceLabel} / 步行約 ${widget.store.walkingMinutes} 分',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.location_on_rounded, widget.store.address),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.schedule_rounded,
            '${widget.store.businessHours} / ${widget.store.isOpenAt(DateTime.now()) ? '目前營業' : '目前未營業'}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeaderTag('商品 ${foods.length} 項'),
              _buildHeaderTag('庫存 $stockTotal 份'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandLogo() {
    final isFamily = widget.store.brand == ConvenienceBrand.familyMart;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: isFamily ? const Color(0xFFE6F4FF) : const Color(0xFFFFF1CC),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        isFamily ? '全家' : '7-11',
        style: TextStyle(
          color: isFamily ? const Color(0xFF1677B7) : const Color(0xFFD86100),
          fontWeight: FontWeight.bold,
          fontSize: isFamily ? 17 : 16,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4E8D57)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4E8D57),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories
            .map(
              (category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (_) => setState(() {
                    _selectedCategory = category;
                  }),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _goToFoodDetail(FoodItem food) {
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
