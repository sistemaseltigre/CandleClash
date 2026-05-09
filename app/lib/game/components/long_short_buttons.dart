import 'package:flutter/material.dart';

import '../../screens/widgets/clash_widgets.dart';

class LongShortButtons extends StatelessWidget {
  const LongShortButtons({
    super.key,
    required this.onLong,
    required this.onShort,
    required this.enabled,
  });

  final VoidCallback onLong;
  final VoidCallback onShort;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TradeButton(
            enabled: enabled,
            onPressed: onLong,
            color: clashGreen,
            icon: Icons.north_east_rounded,
            title: 'UP',
            subtitle: 'PREDICT RISE',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TradeButton(
            enabled: enabled,
            onPressed: onShort,
            color: clashRed,
            icon: Icons.south_east_rounded,
            title: 'DOWN',
            subtitle: 'PREDICT FALL',
          ),
        ),
      ],
    );
  }
}

class _TradeButton extends StatefulWidget {
  const _TradeButton({
    required this.enabled,
    required this.onPressed,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  State<_TradeButton> createState() => _TradeButtonState();
}

class _TradeButtonState extends State<_TradeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool pressed = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final glow = widget.enabled ? 0.20 + controller.value * 0.20 : 0.04;
        return GestureDetector(
          onTapDown: widget.enabled
              ? (_) => setState(() => pressed = true)
              : null,
          onTapCancel: widget.enabled
              ? () => setState(() => pressed = false)
              : null,
          onTapUp: widget.enabled
              ? (_) {
                  setState(() => pressed = false);
                  widget.onPressed();
                }
              : null,
          child: AnimatedScale(
            scale: pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedOpacity(
              opacity: widget.enabled ? 1 : 0.42,
              duration: const Duration(milliseconds: 180),
              child: Container(
                height: 82,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: glow),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.color.withValues(alpha: 0.92),
                      widget.color.withValues(alpha: 0.34),
                      const Color(0xff081018),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -12,
                      top: -18,
                      child: Icon(
                        widget.icon,
                        color: Colors.white.withValues(alpha: 0.10),
                        size: 92,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, size: 34, color: Colors.white),
                          const SizedBox(height: 3),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
