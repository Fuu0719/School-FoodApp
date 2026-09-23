import 'package:flutter/material.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_profile_service.dart';

class MemberLoginForm extends StatefulWidget {
  const MemberLoginForm({
    super.key,
    required this.service,
    this.onLoginComplete,
    this.onMerchantLogin,
  });
  final UserProfileService service;
  final VoidCallback? onLoginComplete;
  final VoidCallback? onMerchantLogin;

  @override
  State<MemberLoginForm> createState() => _MemberLoginFormState();
}

class _MemberLoginFormState extends State<MemberLoginForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _register = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_register) {
        await widget.service.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        widget.onLoginComplete?.call();
      } else {
        await widget.service.login(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (mounted) widget.onLoginComplete?.call();
      }
    } on MemberApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  size: 64,
                  color: Color(0xFF4E8D57),
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('會員登入')),
                    ButtonSegment(value: true, label: Text('建立帳號')),
                  ],
                  selected: {_register},
                  onSelectionChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _register = value.single;
                            _error = null;
                            _notice = null;
                          });
                          _form.currentState?.reset();
                        },
                ),
                const SizedBox(height: 20),
                if (_register)
                  TextFormField(
                    key: const ValueKey('member-name'),
                    controller: _name,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.name],
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: '姓名'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '請輸入姓名' : null,
                  ),
                TextFormField(
                  key: const ValueKey('member-email'),
                  controller: _email,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.username],
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      value != null &&
                          value.length <= 160 &&
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value.trim())
                      ? null
                      : '請輸入有效的 Email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('member-password'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    _register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: '密碼',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? '顯示密碼' : '隱藏密碼',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final max = _register ? 16 : 128;
                    if (value == null ||
                        value.length < 8 ||
                        value.length > max) {
                      return _register ? '請輸入 8 至 16 個字元的密碼' : '請輸入正確的密碼';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!_register) _submit();
                  },
                ),
                if (_register)
                  TextFormField(
                    key: const ValueKey('member-confirmation'),
                    controller: _confirmation,
                    enabled: !_busy,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '確認密碼'),
                    validator: (value) =>
                        value != _password.text ? '兩次密碼不一致' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                if (_error != null || widget.service.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error ?? widget.service.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_notice!),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('member-submit'),
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_register ? Icons.person_add_alt_1 : Icons.login),
                  label: Text(
                    _busy
                        ? '處理中'
                        : _register
                        ? '註冊'
                        : '登入',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : widget.onMerchantLogin,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('商家登入'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
