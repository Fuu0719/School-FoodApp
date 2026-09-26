import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_app/models/purchase_record.dart';

Future<void> showCheckoutSuccess(BuildContext context, PurchaseRecord record) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => CheckoutSuccessOverlay(record: record),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class CheckoutSuccessOverlay extends StatefulWidget {
  const CheckoutSuccessOverlay({super.key, required this.record});

  final PurchaseRecord record;

  @override
  State<CheckoutSuccessOverlay> createState() => _CheckoutSuccessOverlayState();
}

class _CheckoutSuccessOverlayState extends State<CheckoutSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFFFC857),
      Color(0xFF4E8D57),
      Color(0xFFFF7A59),
      Color(0xFF5B8DEF),
    ];
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SizedBox(
            width: 310,
            height: 330,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final burst = Curves.easeOutCubic.transform(
                  _controller.value.clamp(0, 1),
                );
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var index = 0; index < 20; index++)
                      Transform.translate(
                        offset: Offset(
                          math.cos(index * math.pi / 10) * 135 * burst,
                          math.sin(index * math.pi / 10) * 135 * burst,
                        ),
                        child: Opacity(
                          opacity: (1 - _controller.value).clamp(0, 1),
                          child: Icon(
                            index.isEven ? Icons.star_rounded : Icons.circle,
                            size: index.isEven ? 18 : 11,
                            color: colors[index % colors.length],
                          ),
                        ),
                      ),
                    child!,
                  ],
                );
              },
              child: Container(
                width: 270,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FCF7),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 28),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 74,
                      color: Color(0xFF4E8D57),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '點餐成功',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E3A2F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '共 ${widget.record.totalQuantity} 項  NT\$ ${widget.record.totalPrice}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF556157),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '請依門市指示完成取餐',
                      style: TextStyle(color: Color(0xFF748078)),
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
}
