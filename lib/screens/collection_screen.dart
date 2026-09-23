import 'package:flutter/material.dart';
import 'package:my_app/models/food_item.dart';
import 'package:my_app/models/purchase_record.dart';
import 'package:my_app/models/search_log.dart';
import 'package:my_app/screens/food_detail_screen.dart';
import 'package:my_app/screens/search_screen.dart';
import 'package:my_app/services/user_activity_service.dart';
import 'package:my_app/widgets/food_card.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen>
    with SingleTickerProviderStateMixin {
  final UserActivityService _activityService = UserActivityService.instance;
  late final TabController _tabController;
  final TextEditingController _foodSearchController = TextEditingController();
  String _foodQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
    _activityService.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activityService.refreshCloud();
    });
  }

  @override
  void didUpdateWidget(covariant CollectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _activityService.removeListener(_refresh);
    _foodSearchController.dispose();
    _tabController.dispose();
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
        actions: [
          if (_activityService.isCloud)
            IconButton(
              tooltip: '同步收藏與紀錄',
              onPressed: _activityService.isSyncing
                  ? null
                  : _activityService.refreshCloud,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: '清除瀏覽紀錄',
            onPressed: _activityService.isSyncing ? null : _confirmClearHistory,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
        title: const Text(
          '收藏與紀錄',
          style: TextStyle(
            color: Color(0xFF2E3A2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E3A2F)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: const Color(0xFF4E8D57),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF4E8D57),
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: '收藏'),
            Tab(text: '瀏覽紀錄'),
            Tab(text: '搜尋紀錄'),
            Tab(text: '購買紀錄'),
          ],
        ),
      ),
      body: _activityService.isCloud && !_activityService.cloudLoaded
          ? Center(
              child: _activityService.isSyncing
                  ? const CircularProgressIndicator()
                  : const Text('尚未取得紀錄，請點上方同步按鈕重試'),
            )
          : Column(
              children: [
                if (_activityService.isSyncing) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: TextField(
                    controller: _foodSearchController,
                    onChanged: (value) =>
                        setState(() => _foodQuery = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: '搜尋收藏或瀏覽紀錄',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _foodQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除搜尋',
                              onPressed: () {
                                _foodSearchController.clear();
                                setState(() => _foodQuery = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFoodList(
                        foods: _filterFoods(_activityService.favorites),
                        emptyTitle: '尚未收藏餐點',
                        emptyMessage: '在餐點詳情頁按下收藏，之後就能在這裡快速找到。',
                        removable: true,
                      ),
                      _buildFoodList(
                        foods: _filterFoods(_activityService.history),
                        emptyTitle: '尚無瀏覽紀錄',
                        emptyMessage: '點進餐點詳情後，系統會自動留下最近看過的餐點。',
                      ),
                      _buildSearchLogList(_activityService.searchLogs),
                      _buildPurchaseRecordList(
                        _activityService.purchaseRecords,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<FoodItem> _filterFoods(List<FoodItem> foods) {
    if (_foodQuery.isEmpty) return foods;
    return foods
        .where(
          (food) =>
              food.name.toLowerCase().contains(_foodQuery) ||
              food.storeName.toLowerCase().contains(_foodQuery) ||
              food.category.toLowerCase().contains(_foodQuery),
        )
        .toList();
  }

  Widget _buildFoodList({
    required List<FoodItem> foods,
    required String emptyTitle,
    required String emptyMessage,
    bool removable = false,
  }) {
    if (foods.isEmpty) {
      return _buildEmptyState(emptyTitle, emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return FoodCard(
          food: food,
          showDistance: true,
          isFavorite: _activityService.isFavorite(food.id),
          favoriteBusy: _activityService.isFavoriteBusy(food.id),
          variant: food.isExpiringSoon
              ? FoodCardVariant.expiring
              : FoodCardVariant.recommendation,
          onTap: () => _goToFoodDetail(food),
          onFavoritePressed: removable
              ? () => _activityService.toggleFavorite(food)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: Color(0xFF4E8D57),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3A2F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchLogList(List<SearchLog> logs) {
    if (logs.isEmpty) {
      return _buildEmptyState('尚無搜尋紀錄', '送出搜尋後，系統會留下最近查過的關鍵字與篩選條件。');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '最近搜尋',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3A2F),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _activityService.clearSearchLogs,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('清除'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...logs.map((log) => _buildSearchLogTile(log)),
      ],
    );
  }

  Widget _buildPurchaseRecordList(List<PurchaseRecord> records) {
    if (records.isEmpty) {
      return _buildEmptyState('尚無購買紀錄', '完成結帳後，系統會將本次購買的餐點與金額留在這裡。');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          '購買紀錄',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3A2F),
          ),
        ),
        const SizedBox(height: 12),
        ...records.map(_buildPurchaseRecordTile),
        if (_activityService.hasMoreOrders)
          TextButton(
            onPressed: _activityService.isSyncing
                ? null
                : _activityService.loadMoreOrders,
            child: const Text('載入較早訂單'),
          ),
      ],
    );
  }

  Widget _buildPurchaseRecordTile(PurchaseRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF4E8D57),
            ),
          ),
          title: Text(
            '訂單 ${record.purchasedAtLabel}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E3A2F),
            ),
          ),
          subtitle: Text(
            '${record.summaryLabel}${record.isCloud ? '（模擬訂單，未付款）' : ''}',
          ),
          children: record.items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.food.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'x${item.quantity}  NT\$ ${item.subtotal}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3A2F),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSearchLogTile(SearchLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () => _goToSearch(log),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5E8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.search_rounded, color: Color(0xFF4E8D57)),
        ),
        title: Text(
          log.displayTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3A2F),
          ),
        ),
        subtitle: Text(log.displaySubtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              log.searchedAtLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有瀏覽紀錄？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _activityService.clearHistory();
  }

  void _goToSearch(SearchLog log) {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialQuery: log.keyword),
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

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
