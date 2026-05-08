import 'package:flutter/material.dart';

const clashBg = Color(0xff080f19);
const clashPanel = Color(0xff0d1621);
const clashBorder = Color(0xff1c2a36);
const clashGreen = Color(0xff00ff6a);
const clashRed = Color(0xffff3b3b);
const clashYellow = Color(0xffffd33d);
const clashPurple = Color(0xff9945ff);

class ClashLogo extends StatelessWidget {
  const ClashLogo({super.key, this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/logo.jpeg',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}

class ClashPanel extends StatelessWidget {
  const ClashPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: clashPanel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: clashBorder),
        boxShadow: [
          BoxShadow(
            color: clashGreen.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class NeonStat extends StatelessWidget {
  const NeonStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = clashGreen,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xff09111a),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class ClashBottomNav extends StatelessWidget {
  const ClashBottomNav({super.key, required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClashPanel(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              _NavItem(label: 'Play', icon: Icons.home_rounded, route: '/', active: current == 'play'),
              _NavItem(label: 'Board', icon: Icons.emoji_events, route: '/leaderboard', active: current == 'leaderboard'),
              _NavItem(label: 'Wallet', icon: Icons.account_balance_wallet, route: '/wallet', active: current == 'wallet'),
              _NavItem(label: 'Game', icon: Icons.candlestick_chart, route: '/game', active: current == 'game'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.active,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? clashGreen : Colors.white54;
    return Expanded(
      child: InkWell(
        onTap: active ? null : () => Navigator.pushReplacementNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
