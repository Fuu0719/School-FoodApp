import 'package:flutter/material.dart';
import 'package:my_app/screens/home_screen.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/merchant_auth_service.dart';
import 'package:my_app/services/user_profile_service.dart';

class MerchantAccountScreen extends StatefulWidget {
  const MerchantAccountScreen({super.key, required this.service});
  final MerchantAuthService service;

  @override
  State<MerchantAccountScreen> createState() => _MerchantAccountScreenState();
}

class _MerchantAccountScreenState extends State<MerchantAccountScreen> {
  final form = GlobalKey<FormState>();
  late final businessName = TextEditingController(
    text: widget.service.account!.businessName,
  );
  late final phone = TextEditingController(
    text: widget.service.account!.contactPhone,
  );
  String? message;

  @override
  void dispose() {
    businessName.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => message = null);
    try {
      await action();
    } on MemberApiException catch (error) {
      if (mounted) setState(() => message = error.message);
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    await _run(() async {
      await widget.service.updateAccount(
        businessName.text.trim(),
        phone.text.trim(),
      );
      if (mounted) setState(() => message = '商家資料已更新');
    });
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改商家密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: '目前密碼'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密碼（8 至 16 字元）'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: '再次輸入新密碼'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    if (next.text != confirm.text) {
      setState(() => message = '兩次新密碼不一致');
      return;
    }
    await _run(() async {
      await widget.service.changePassword(current.text, next.text);
      if (mounted) setState(() => message = '密碼已更新，其他商家登入已登出');
    });
  }

  Future<void> _linkAndSwitch() async {
    Map<String, dynamic> response;
    if (widget.service.account!.linkedMember == null) {
      final email = TextEditingController();
      final password = TextEditingController();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('綁定會員帳號'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '會員 Email'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '會員密碼'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('綁定並切換'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      try {
        response = await widget.service.linkMember(
          email.text.trim(),
          password.text,
        );
      } on MemberApiException catch (error) {
        if (mounted) setState(() => message = error.message);
        return;
      }
    } else {
      try {
        response = await widget.service.switchToMember();
      } on MemberApiException catch (error) {
        if (mounted) setState(() => message = error.message);
        return;
      }
    }
    await UserProfileService.instance.acceptLinkedSession(response);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _unlink() => _run(() async {
    await widget.service.unlinkMember();
    if (mounted) setState(() => message = '已解除會員綁定');
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.service,
    builder: (context, _) {
      final account = widget.service.account!;
      return Scaffold(
        appBar: AppBar(title: const Text('商家帳號與資料')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Form(
                  key: form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: businessName,
                        enabled: !widget.service.isBusy,
                        decoration: const InputDecoration(
                          labelText: '商家名稱',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '請輸入商家名稱'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        enabled: !widget.service.isBusy,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: '聯絡電話',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mail_outline),
                        title: const Text('登入 Email'),
                        subtitle: Text(account.email),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.service.isBusy ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('儲存商家資料'),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 36),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: const Text('綁定會員'),
                  subtitle: Text(account.linkedMember?.name ?? '尚未設定'),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.service.isBusy ? null : _linkAndSwitch,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      account.linkedMember == null ? '綁定會員並切換' : '切換會員帳號',
                    ),
                  ),
                ),
                if (account.linkedMember != null)
                  TextButton.icon(
                    onPressed: widget.service.isBusy ? null : _unlink,
                    icon: const Icon(Icons.link_off),
                    label: const Text('解除會員綁定'),
                  ),
                const Divider(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.service.isBusy ? null : _changePassword,
                    icon: const Icon(Icons.password),
                    label: const Text('修改商家密碼'),
                  ),
                ),
                if (widget.service.isBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(message!, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
