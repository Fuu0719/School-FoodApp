import 'package:flutter/material.dart';
import 'package:my_app/models/merchant_product.dart';
import 'package:my_app/services/merchant_auth_service.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/screens/merchant_product_editor.dart';
import 'package:my_app/screens/merchant_register_screen.dart';

class CloudMerchantLoginScreen extends StatefulWidget {
  const CloudMerchantLoginScreen({super.key, this.service});
  final MerchantAuthService? service;
  @override
  State<CloudMerchantLoginScreen> createState() =>
      _CloudMerchantLoginScreenState();
}

class _CloudMerchantLoginScreenState extends State<CloudMerchantLoginScreen> {
  late final service = widget.service ?? MerchantAuthService.instance;
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool obscure = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await service.initialize();
        if (mounted && service.isLoggedIn) _open();
      } on MemberApiException catch (e) {
        if (mounted) setState(() => error = e.message);
      }
    });
  }

  void _open() => Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MerchantProductsScreen(service: service),
    ),
  );
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!form.currentState!.validate()) return;
    setState(() => error = null);
    try {
      await service.login(email.text.trim(), password.text);
      if (mounted) _open();
    } on MemberApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _register() async {
    final registeredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantRegisterScreen(service: service),
      ),
    );
    if (registeredEmail != null && mounted) {
      setState(() {
        email.text = registeredEmail;
        password.clear();
        error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => PopScope(
      canPop: !service.isBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('商家登入')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: Color(0xFF4E8D57),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: email,
                    enabled: !service.isBusy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: '商家 Email'),
                    validator: (v) =>
                        v == null ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                        ? '請輸入有效 Email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    enabled: !service.isBusy,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: '密碼',
                      suffixIcon: IconButton(
                        tooltip: obscure ? '顯示密碼' : '隱藏密碼',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.length < 12 || v.length > 128
                        ? '密碼須為 12 至 128 個字元'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: service.isBusy ? null : _login,
                    icon: const Icon(Icons.login),
                    label: Text(service.isBusy ? '登入中' : '登入商家後台'),
                  ),
                  TextButton(
                    onPressed: service.isBusy ? null : _register,
                    child: const Text('註冊商家帳號'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key, this.service});
  final MerchantAuthService? service;
  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  late final service = widget.service ?? MerchantAuthService.instance;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && service.isLoggedIn) _act(() => service.refresh());
    });
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => error = null);
    try {
      await action();
    } on MemberApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _edit([MerchantProduct? product]) async {
    if (product != null) {
      try {
        product = await service.detail(product.id);
      } on MemberApiException catch (e) {
        if (mounted) setState(() => error = e.message);
        return;
      }
      if (product.status == 'active') {
        if (mounted) setState(() => error = '請先下架再編輯商品');
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            MerchantProductEditor(service: service, product: product),
      ),
    );
  }

  Future<void> _status(MerchantProduct product) async {
    final status = product.status == 'active' ? 'paused' : 'active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'active' ? '上架此商品？' : '下架此商品？'),
        content: Text(product.input.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _act(() => service.setStatus(product, status));
    }
  }

  void _login() => Navigator.pushReplacement(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CloudMerchantLoginScreen(service: service),
    ),
  );
  Future<void> _logout() => _act(() async {
    await service.logout();
    if (mounted) _login();
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => PopScope(
      canPop: !service.isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('商家商品'),
          actions: [
            IconButton(
              tooltip: '重新載入',
              onPressed: service.isBusy || !service.isLoggedIn
                  ? null
                  : () => _act(() => service.refresh()),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '商家登出',
              onPressed: service.isBusy || !service.isLoggedIn ? null : _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: !service.isLoggedIn
            ? Center(
                child: FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: const Text('重新登入商家'),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      if (service.isBusy) const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              service.account!.businessName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed:
                                  service.isBusy ||
                                      service.pendingCorrupt ||
                                      (service.account!.stores.isEmpty &&
                                          !service.hasPendingDraft)
                                  ? null
                                  : () => _edit(),
                              icon: Icon(
                                service.hasPendingDraft
                                    ? Icons.sync
                                    : Icons.add,
                              ),
                              label: Text(
                                service.hasPendingDraft ? '確認待建立草稿' : '新增商品',
                              ),
                            ),
                            if (service.account!.stores.isEmpty)
                              const Text('尚未分配可管理門市'),
                            if (service.pendingCorrupt)
                              const Text('待確認草稿資料異常，請聯絡管理者'),
                            if (error != null)
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: !service.loaded && service.products.isEmpty
                            ? Center(
                                child: Text(service.isBusy ? '載入中' : '尚未取得商品'),
                              )
                            : service.products.isEmpty
                            ? const Center(child: Text('尚無商品'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    service.products.length +
                                    (service.hasMore ? 1 : 0),
                                separatorBuilder: (_, _) => const Divider(),
                                itemBuilder: (context, index) {
                                  if (index == service.products.length) {
                                    return TextButton(
                                      onPressed: service.isBusy
                                          ? null
                                          : () => _act(
                                              () => service.refresh(more: true),
                                            ),
                                      child: const Text('載入更多商品'),
                                    );
                                  }
                                  final product = service.products[index];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: product.input.imageUrl.isEmpty
                                            ? const Icon(Icons.image_outlined)
                                            : Image.network(
                                                product.input.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    ),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.input.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(product.storeName),
                                            Text(
                                              'NT\$ ${product.input.price} · 庫存 ${product.input.stockCount}',
                                            ),
                                            Text(
                                              product.statusLabel,
                                              style: TextStyle(
                                                color:
                                                    product.status == 'active'
                                                    ? const Color(0xFF367242)
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: '商品操作',
                                        enabled: !service.isBusy,
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _edit(product);
                                          } else {
                                            _status(product);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (product.status != 'active')
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('編輯'),
                                            ),
                                          PopupMenuItem(
                                            value: 'status',
                                            child: Text(
                                              product.status == 'active'
                                                  ? '下架'
                                                  : '上架',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
