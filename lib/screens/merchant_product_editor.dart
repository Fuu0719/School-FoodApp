import 'package:flutter/material.dart';
import 'package:my_app/models/merchant_product.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/merchant_auth_service.dart';

class MerchantProductEditor extends StatefulWidget {
  const MerchantProductEditor({super.key, required this.service, this.product});
  final MerchantAuthService service;
  final MerchantProduct? product;
  @override
  State<MerchantProductEditor> createState() => _MerchantProductEditorState();
}

class _MerchantProductEditorState extends State<MerchantProductEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String storeId;
  String category = '便當';
  final addedCategories = <String>{};
  bool expiring = false;
  DateTime? expires;
  String? error;
  bool get pending => widget.product == null && widget.service.hasPendingDraft;
  static const textFields = [
    ('name', '餐點名稱'),
    ('tags', '標籤（逗號分隔）'),
    ('ingredients', '食材（逗號分隔）'),
    ('imageUrl', '圖片 HTTPS 網址'),
  ];
  static const numberFields = [
    ('price', '售價', 1000000),
    ('originalPrice', '原價（選填）', 1000000),
    ('stockCount', '庫存', 1000000),
    ('calories', '熱量 kcal', 10000),
    ('weightGrams', '重量 g', 10000),
    ('proteinGrams', '蛋白質 g', 10000),
    ('fatGrams', '脂肪 g', 10000),
    ('carbsGrams', '碳水 g', 10000),
  ];
  @override
  void initState() {
    super.initState();
    final input = widget.product?.input ?? widget.service.pendingInput;
    storeId = input?.storeId ?? widget.service.account!.stores.first.id;
    category = input?.category ?? category;
    expiring = input?.isExpiringSoon ?? false;
    expires = input?.expiresAt?.toLocal();
    final json = input?.toJson();
    for (final field in [
      ...textFields.map((v) => v.$1),
      ...numberFields.map((v) => v.$1),
    ]) {
      final value = json?[field];
      fields[field] = TextEditingController(
        text: value is List
            ? value.join('、')
            : value?.toString() ??
                  (numberFields.any((v) => v.$1 == field) &&
                          field != 'originalPrice'
                      ? '0'
                      : ''),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _expiry() async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year + 10);
    final date = await showDatePicker(
      context: context,
      initialDate:
          expires != null &&
              expires!.isAfter(now) &&
              expires!.isBefore(lastDate)
          ? expires
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(expires ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => expires = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _addCategory() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (selected == null || !mounted) return;
    final choices = {
      ...widget.service.categories,
      ...addedCategories,
      category,
    };
    final existing = choices.where(
      (choice) => choice.toLowerCase() == selected.toLowerCase(),
    );
    setState(() {
      category = existing.isEmpty ? selected : existing.first;
      addedCategories.add(category);
    });
  }

  List<String> _list(String field) => fields[field]!.text
      .split(RegExp(r'[,，、]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  Future<void> _save() async {
    if (!pending && !form.currentState!.validate()) return;
    if (!pending && expiring && expires == null) {
      setState(() => error = '即期餐點須填寫保存期限');
      return;
    }
    setState(() => error = null);
    final MerchantProductInput input;
    if (pending) {
      input = widget.service.pendingInput!;
    } else {
      int number(String key) => int.parse(fields[key]!.text.trim());
      input = MerchantProductInput(
        storeId: storeId,
        name: fields['name']!.text.trim(),
        category: category,
        price: number('price'),
        originalPrice: int.tryParse(fields['originalPrice']!.text.trim()),
        stockCount: number('stockCount'),
        imageUrl: fields['imageUrl']!.text.trim(),
        calories: number('calories'),
        weightGrams: number('weightGrams'),
        proteinGrams: number('proteinGrams'),
        fatGrams: number('fatGrams'),
        carbsGrams: number('carbsGrams'),
        tags: _list('tags'),
        ingredients: _list('ingredients'),
        expiresAt: expires,
        isExpiringSoon: expiring,
      );
    }
    try {
      await widget.service.save(input, existing: widget.product);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('草稿已儲存，尚未上架')));
      Navigator.pop(context);
    } on MemberApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final categories = {...service.categories, ...addedCategories, category};
      final stores = service.account?.stores ?? [];
      return PopScope(
        canPop: !service.isBusy,
        child: Scaffold(
          appBar: AppBar(title: Text(widget.product == null ? '新增商品' : '編輯商品')),
          body: !service.isLoggedIn
              ? const Center(child: Text('商家登入已失效，請返回重新登入'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Form(
                      key: form,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          AbsorbPointer(
                            absorbing: service.isBusy || pending,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      stores.any((s) => s.id == storeId)
                                      ? storeId
                                      : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '所屬門市',
                                  ),
                                  items: stores
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s.id,
                                          child: Text(
                                            s.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: widget.product != null
                                      ? null
                                      : (v) {
                                          if (v != null) {
                                            setState(() => storeId = v);
                                          }
                                        },
                                  validator: (v) =>
                                      v == null ? '請選擇可管理門市' : null,
                                ),
                                const SizedBox(height: 12),
                                _text('name', '餐點名稱', required: true),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('category:$category'),
                                  initialValue: category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '分類',
                                  ),
                                  items: categories
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(
                                            v,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => category = v);
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: '新增分類',
                                    onPressed: service.isBusy || pending
                                        ? null
                                        : _addCategory,
                                    icon: const Icon(Icons.add),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...numberFields.map(
                                  (field) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextFormField(
                                      controller: fields[field.$1],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: field.$2,
                                      ),
                                      validator: (value) {
                                        if (field.$1 == 'originalPrice' &&
                                            (value ?? '').trim().isEmpty) {
                                          return null;
                                        }
                                        final number = int.tryParse(
                                          (value ?? '').trim(),
                                        );
                                        if (number == null ||
                                            number < 0 ||
                                            number > field.$3) {
                                          return '請輸入 0 至 ${field.$3} 的整數';
                                        }
                                        if (field.$1 == 'originalPrice' &&
                                            number <
                                                (int.tryParse(
                                                      fields['price']!.text,
                                                    ) ??
                                                    0)) {
                                          return '原價不可低於售價';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                                _text('tags', '標籤（逗號分隔）'),
                                _text('ingredients', '食材（逗號分隔）'),
                                _text('imageUrl', '圖片 HTTPS 網址'),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('即期餐點'),
                                  value: expiring,
                                  onChanged: (value) =>
                                      setState(() => expiring = value),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('保存期限（本機時間）'),
                                  subtitle: Text(
                                    expires == null
                                        ? '未設定'
                                        : '${expires!.year}/${expires!.month}/${expires!.day} ${TimeOfDay.fromDateTime(expires!).format(context)}',
                                  ),
                                  onTap: _expiry,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: '選擇保存期限',
                                        onPressed: _expiry,
                                        icon: const Icon(Icons.event),
                                      ),
                                      if (expires != null)
                                        IconButton(
                                          tooltip: '清除保存期限',
                                          onPressed: () =>
                                              setState(() => expires = null),
                                          icon: const Icon(Icons.clear),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: service.isBusy || service.pendingCorrupt
                                ? null
                                : _save,
                            icon: Icon(
                              pending ? Icons.sync : Icons.save_outlined,
                            ),
                            label: Text(
                              service.isBusy
                                  ? '儲存中'
                                  : pending
                                  ? '確認原草稿'
                                  : '儲存草稿',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
  Widget _text(String key, String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: fields[key],
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          required && (value ?? '').trim().isEmpty ? '此欄位不可空白' : null,
    ),
  );
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();
  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final form = GlobalKey<FormState>();
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增分類'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(labelText: '分類名稱'),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => submit(),
        validator: (value) {
          final name = (value ?? '').trim();
          if (name.isEmpty) return '請輸入分類名稱';
          if (name.length > 40) return '分類最多 40 個字元';
          if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) return '分類不可含換行或控制字元';
          return null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: submit, child: const Text('新增')),
    ],
  );
}
