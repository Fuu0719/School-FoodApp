import 'package:flutter/material.dart';
import 'package:my_app/data/food_catalog_repository.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/screens/food_detail_screen.dart';
import 'package:my_app/services/food_search_service.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/widgets/food_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialFilters = const FoodSearchFilters(),
  });

  final String initialQuery;
  final FoodSearchFilters initialFilters;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FoodSearchService _searchService = const FoodSearchService();
  final UserActivityService _activityService = UserActivityService.instance;
  late final TextEditingController _searchController;
  FoodSearchFilters _filters = const FoodSearchFilters();
  FoodSearchSortOption _sortOption = FoodSearchSortOption.recommended;
  late List<FoodItem> _results;

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
    _searchController = TextEditingController(text: widget.initialQuery);
    _filters = widget.initialFilters;
    _results = _search();
    _activityService.addListener(_refresh);
  }

  @override
  void dispose() {
    _activityService.removeListener(_refresh);
    _searchController.dispose();
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
          '搜尋餐點',
          style: TextStyle(
            color: Color(0xFF2E3A2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
        actions: [
          IconButton(
            tooltip: '篩選',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                onChanged: (_) => _refreshResults(),
                decoration: InputDecoration(
                  hintText: '餐點、商家、食材或標籤',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除',
                          onPressed: () {
                            _searchController.clear();
                            _refreshResults();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            _buildRecentSearches(),
            _buildActiveFilters(),
            _buildSortBar(),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.sort_rounded, color: Color(0xFF4E8D57), size: 20),
          const SizedBox(width: 8),
          const Text(
            '排序',
            style: TextStyle(
              color: Color(0xFF2E3A2F),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<FoodSearchSortOption>(
              initialValue: _sortOption,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: FoodSearchSortOption.values
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (option) {
                if (option == null) {
                  return;
                }

                _updateSortOption(option);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[
      if (_filters.expiringOnly)
        InputChip(
          label: const Text('只看即期'),
          onDeleted: () =>
              _updateFilters(_filters.copyWith(expiringOnly: false)),
        ),
      ..._filters.categories.map(
        (category) => InputChip(
          label: Text(category),
          onDeleted: () => _toggleCategory(category),
        ),
      ),
      ..._filters.tags.map(
        (tag) => InputChip(label: Text(tag), onDeleted: () => _toggleTag(tag)),
      ),
      if (_filters.maxPrice != null)
        InputChip(
          label: Text('${_filters.maxPrice} 元內'),
          onDeleted: () =>
              _updateFilters(_filters.copyWith(clearMaxPrice: true)),
        ),
      if (_filters.maxDistanceMeters != null)
        InputChip(
          label: Text('${_filters.maxDistanceMeters} 公尺內'),
          onDeleted: () =>
              _updateFilters(_filters.copyWith(clearMaxDistance: true)),
        ),
    ];

    if (chips.isEmpty) {
      return const SizedBox(height: 8);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(children: chips),
    );
  }

  Widget _buildRecentSearches() {
    final logs = _activityService.searchLogs;
    if (_searchController.text.isNotEmpty || logs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: Color(0xFF4E8D57)),
              SizedBox(width: 6),
              Text(
                '最近搜尋',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3A2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: logs
                .map(
                  (log) => ActionChip(
                    label: Text(log.displayTitle),
                    avatar: const Icon(Icons.search_rounded, size: 18),
                    onPressed: () {
                      _searchController.text = log.keyword;
                      _refreshResults();
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return const Center(
        child: Text('找不到符合條件的餐點', style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final food = _results[index];
        return FoodCard(
          food: food,
          showDistance: true,
          variant: food.isExpiringSoon
              ? FoodCardVariant.expiring
              : FoodCardVariant.recommendation,
          isFavorite: _activityService.isFavorite(food.id),
          favoriteBusy: _activityService.isFavoriteBusy(food.id),
          onTap: () => _goToFoodDetail(food),
          onFavoritePressed: () => _activityService.toggleFavorite(food),
        );
      },
    );
  }

  void _openFilters() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        var draftFilters = _filters;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateDraft(FoodSearchFilters filters) {
              setSheetState(() {
                draftFilters = filters;
              });
            }

            return SafeArea(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                shrinkWrap: true,
                children: [
                  const Text(
                    '篩選條件',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E3A2F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('只看即期優惠'),
                    value: draftFilters.expiringOnly,
                    onChanged: (value) =>
                        updateDraft(draftFilters.copyWith(expiringOnly: value)),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterSection(
                    title: '餐點類型',
                    children: _categories
                        .map(
                          (category) => FilterChip(
                            label: Text(category),
                            selected: draftFilters.categories.contains(
                              category,
                            ),
                            onSelected: (_) => updateDraft(
                              _filtersWithCategory(draftFilters, category),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _buildFilterSection(
                    title: '偏好標籤',
                    children: _tags
                        .map(
                          (tag) => FilterChip(
                            label: Text(tag),
                            selected: draftFilters.tags.contains(tag),
                            onSelected: (_) =>
                                updateDraft(_filtersWithTag(draftFilters, tag)),
                          ),
                        )
                        .toList(),
                  ),
                  _buildPriceOptions(draftFilters, updateDraft),
                  _buildDistanceOptions(draftFilters, updateDraft),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              updateDraft(const FoodSearchFilters()),
                          child: const Text('清除'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            _updateFilters(draftFilters);
                            Navigator.pop(context);
                          },
                          child: const Text('套用'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildPriceOptions(
    FoodSearchFilters draftFilters,
    ValueChanged<FoodSearchFilters> onChanged,
  ) {
    const options = [80, 120, 150];

    return _buildFilterSection(
      title: '預算上限',
      children: options
          .map(
            (price) => ChoiceChip(
              label: Text('$price 元內'),
              selected: draftFilters.maxPrice == price,
              onSelected: (selected) => onChanged(
                draftFilters.copyWith(
                  maxPrice: selected ? price : null,
                  clearMaxPrice: !selected,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDistanceOptions(
    FoodSearchFilters draftFilters,
    ValueChanged<FoodSearchFilters> onChanged,
  ) {
    const options = [500, 800, 1000];

    return _buildFilterSection(
      title: '距離上限',
      children: options
          .map(
            (distance) => ChoiceChip(
              label: Text('$distance 公尺內'),
              selected: draftFilters.maxDistanceMeters == distance,
              onSelected: (selected) => onChanged(
                draftFilters.copyWith(
                  maxDistanceMeters: selected ? distance : null,
                  clearMaxDistance: !selected,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _refreshResults() {
    setState(() {
      _results = _search();
    });
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    _activityService.addSearchLog(
      keyword: _searchController.text,
      filterSummary: _filters.summaryLabel,
    );
  }

  void _updateFilters(FoodSearchFilters filters) {
    setState(() {
      _filters = filters;
      _results = _search();
    });
  }

  void _updateSortOption(FoodSearchSortOption sortOption) {
    setState(() {
      _sortOption = sortOption;
      _results = _search();
    });
  }

  void _toggleCategory(String category) {
    _updateFilters(_filtersWithCategory(_filters, category));
  }

  void _toggleTag(String tag) {
    _updateFilters(_filtersWithTag(_filters, tag));
  }

  FoodSearchFilters _filtersWithCategory(
    FoodSearchFilters filters,
    String category,
  ) {
    final categories = {...filters.categories};
    categories.contains(category)
        ? categories.remove(category)
        : categories.add(category);
    return filters.copyWith(categories: categories);
  }

  FoodSearchFilters _filtersWithTag(FoodSearchFilters filters, String tag) {
    final tags = {...filters.tags};
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    return filters.copyWith(tags: tags);
  }

  List<FoodItem> _search() {
    return _searchService.search(
      foods: FoodCatalogRepository.instance.allFoods,
      query: _searchController.text,
      filters: _filters,
      sortOption: _sortOption,
    );
  }

  void _goToFoodDetail(FoodItem food) {
    FocusScope.of(context).unfocus();
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
