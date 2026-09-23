import 'package:flutter/material.dart';
import 'package:my_app/validation/phone.dart';
import 'package:flutter/cupertino.dart';
import 'package:my_app/models/merchant_registration.dart';
import 'package:my_app/services/merchant_auth_service.dart';
import 'package:my_app/services/member_api.dart';

class MerchantRegisterScreen extends StatefulWidget {
  const MerchantRegisterScreen({
    super.key,
    required this.service,
    this.createStore = false,
  });
  final MerchantAuthService service;
  final bool createStore;
  @override
  State<MerchantRegisterScreen> createState() => _MerchantRegisterScreenState();
}

class _MerchantRegisterScreenState extends State<MerchantRegisterScreen> {
  final form = GlobalKey<FormState>();
  static const fields = [
    ('businessName', '商家名稱', 120),
    ('email', '商家 Email', 160),
    ('password', '密碼', 128),
    ('confirm', '確認密碼', 128),
    ('storeName', '門市名稱', 120),
    ('address', '門市地址', 255),
    ('contactPhone', '聯絡電話（選填）', 40),
  ];
  final controllers = {
    for (final field in fields) field.$1: TextEditingController(),
  };
  final days = <int>{};
  TimeOfDay opensAt = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay closesAt = const TimeOfDay(hour: 18, minute: 0);
  String timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> pickTime(bool opening) async {
    var value = opening ? opensAt : closesAt;
    final selected = await showModalBottomSheet<TimeOfDay>(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  Text(opening ? '開始營業' : '結束營業'),
                  TextButton(
                    onPressed: () => Navigator.pop(context, value),
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    2026,
                    1,
                    1,
                    value.hour,
                    value.minute,
                  ),
                  onDateTimeChanged: (date) =>
                      value = TimeOfDay(hour: date.hour, minute: date.minute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        if (opening) {
          opensAt = selected;
        } else {
          closesAt = selected;
        }
      });
    }
  }

  String? error;
  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!form.currentState!.validate()) return;
    if (widget.createStore && days.isEmpty) {
      setState(() => error = '請至少選擇一個營業日');
      return;
    }
    setState(() => error = null);
    String value(String key) => controllers[key]!.text.trim();
    try {
      if (widget.createStore) {
        await widget.service.createStore({
          'storeName': value('storeName'),
          'address': value('address'),
          'contactPhone': value('contactPhone'),
          'opensAt': timeLabel(opensAt),
          'closesAt': timeLabel(closesAt),
          'businessWeekdays': days.toList()..sort(),
        });
        if (mounted) Navigator.pop(context);
        return;
      }
      await widget.service.register(
        MerchantRegistration(
          email: value('email'),
          password: controllers['password']!.text,
          businessName: value('businessName'),
          contactPhone: value('contactPhone'),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商家註冊成功，請登入')));
      Navigator.pop(context, value('email'));
    } on MemberApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.service,
    builder: (context, _) => PopScope(
      canPop: !widget.service.isBusy,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.createStore ? '新增門市' : '商家註冊')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ...fields
                      .where(
                        (field) =>
                            field.$1 == 'contactPhone' ||
                            (widget.createStore
                                ? ['storeName', 'address'].contains(field.$1)
                                : [
                                    'businessName',
                                    'email',
                                    'password',
                                    'confirm',
                                  ].contains(field.$1)),
                      )
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: controllers[field.$1],
                            enabled: !widget.service.isBusy,
                            obscureText:
                                field.$1 == 'password' || field.$1 == 'confirm',
                            keyboardType: field.$1 == 'email'
                                ? TextInputType.emailAddress
                                : field.$1 == 'contactPhone'
                                ? TextInputType.phone
                                : TextInputType.text,
                            decoration: InputDecoration(labelText: field.$2),
                            validator: (input) {
                              final value = input ?? '';
                              if (field.$1 == 'contactPhone') {
                                return validateOptionalPhone(value);
                              }
                              if (field.$1 == 'password' ||
                                  field.$1 == 'confirm') {
                                if (value.length < 12 || value.length > 128) {
                                  return '密碼須為 12 至 128 個字元';
                                }
                                if (field.$1 == 'confirm' &&
                                    value != controllers['password']!.text) {
                                  return '兩次密碼不一致';
                                }
                              } else {
                                if (field.$1 != 'contactPhone' &&
                                    value.trim().isEmpty) {
                                  return '此欄位不可空白';
                                }
                                if (value.trim().length > field.$3) {
                                  return '最多 ${field.$3} 個字元';
                                }
                                if (field.$1 == 'email' &&
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(value.trim())) {
                                  return '請輸入有效 Email';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                  if (widget.createStore) ...[
                    ListTile(
                      title: const Text('開始營業'),
                      trailing: Text(timeLabel(opensAt)),
                      onTap: widget.service.isBusy
                          ? null
                          : () => pickTime(true),
                    ),
                    ListTile(
                      title: const Text('結束營業'),
                      trailing: Text(
                        '${timeLabel(closesAt)}${closesAt.hour * 60 + closesAt.minute < opensAt.hour * 60 + opensAt.minute ? '（翌日）' : ''}',
                      ),
                      onTap: widget.service.isBusy
                          ? null
                          : () => pickTime(false),
                    ),
                    const Text(
                      '營業日',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children: List.generate(
                        7,
                        (index) => FilterChip(
                          label: Text(
                            const [
                              '週一',
                              '週二',
                              '週三',
                              '週四',
                              '週五',
                              '週六',
                              '週日',
                            ][index],
                          ),
                          selected: days.contains(index + 1),
                          onSelected: widget.service.isBusy
                              ? null
                              : (selected) => setState(() {
                                  if (selected) {
                                    days.add(index + 1);
                                  } else {
                                    days.remove(index + 1);
                                  }
                                }),
                        ),
                      ),
                    ),
                  ],
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
                    onPressed: widget.service.isBusy ? null : _register,
                    icon: const Icon(Icons.person_add_outlined),
                    label: Text(
                      widget.service.isBusy
                          ? '處理中'
                          : widget.createStore
                          ? '建立門市'
                          : '建立商家帳號',
                    ),
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
