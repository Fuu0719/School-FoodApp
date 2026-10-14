import 'package:flutter/material.dart';

class BrandLaunchGate extends StatefulWidget {
  const BrandLaunchGate({
    super.key,
    required this.initialization,
    required this.child,
  });

  final Future<void>? initialization;
  final Widget child;

  @override
  State<BrandLaunchGate> createState() => _BrandLaunchGateState();
}

class _BrandLaunchGateState extends State<BrandLaunchGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialization == null) {
      _ready = true;
    } else {
      _start();
    }
  }

  Future<void> _start() async {
    await Future.wait([
      widget.initialization!,
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: _ready
          ? KeyedSubtree(
              key: const ValueKey('app-content'),
              child: widget.child,
            )
          : ColoredBox(
              key: const ValueKey('brand-splash'),
              color: const Color(0xFF0A4630),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          'assets/branding/mealmind_intro.webp',
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
