import 'package:flutter/material.dart';
import 'package:my_app/services/member_api.dart';
import 'package:my_app/services/user_profile_service.dart';
import 'package:my_app/widgets/brand_logo.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    required this.service,
    this.initialEmail = '',
  });

  final UserProfileService service;
  final String initialEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.service.requestPasswordReset(_email.text.trim());
      if (mounted) {
        setState(() {
          _codeSent = true;
          _notice = '若此 Email 已註冊，驗證碼已寄出，有效時間 10 分鐘。';
        });
      }
    } on MemberApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resetToken = await widget.service.verifyPasswordResetCode(
        email: _email.text.trim(),
        code: _code.text.trim(),
      );
      if (!mounted) return;
      final message = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => NewPasswordScreen(
            service: widget.service,
            resetToken: resetToken,
          ),
        ),
      );
      if (message != null && mounted) Navigator.of(context).pop(message);
    } on MemberApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        title: const Text('忘記密碼'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const Center(child: BrandLogo(size: 72)),
              const SizedBox(height: 18),
              Text(
                '步驟 1／2',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF4E8D57),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '驗證你的 Email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('先輸入帳號 Email 取得 6 位數驗證碼。驗證正確後，才會進入設定新密碼頁面。'),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('reset-email'),
                controller: _email,
                enabled: !_codeSent && !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) =>
                    value != null &&
                        value.length <= 160 &&
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(value.trim())
                    ? null
                    : '請輸入有效的 Email',
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('reset-code'),
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '6 位數驗證碼',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                  validator: (value) =>
                      RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : '請輸入 6 位數驗證碼',
                  onFieldSubmitted: (_) => _verifyCode(),
                ),
              ],
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_notice!),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('reset-primary'),
                onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _codeSent ? Icons.arrow_forward : Icons.send_outlined,
                      ),
                label: Text(_codeSent ? '驗證並進入下一步' : '寄送驗證碼'),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('重新寄送驗證碼'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    required this.service,
    required this.resetToken,
  });
  final UserProfileService service;
  final String resetToken;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.resetPassword(
        resetToken: widget.resetToken,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop('密碼已更新，請使用新密碼登入');
    } on MemberApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F4),
        title: const Text('設定新密碼'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: [
              const Icon(
                Icons.lock_reset_rounded,
                size: 58,
                color: Color(0xFF4E8D57),
              ),
              const SizedBox(height: 18),
              Text(
                '步驟 2／2',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF4E8D57),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '建立新的登入密碼',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('new-password'),
                controller: _password,
                obscureText: _obscure,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: '新密碼（8 至 16 個字元）',
                  prefixIcon: const Icon(Icons.lock_outline),
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
                validator: (value) =>
                    value != null && value.length >= 8 && value.length <= 16
                    ? null
                    : '請輸入 8 至 16 個字元的密碼',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('new-password-confirmation'),
                controller: _confirmation,
                obscureText: true,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: '再次輸入新密碼',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) =>
                    value == _password.text ? null : '兩次密碼不一致',
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('save-new-password'),
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('更新密碼'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
