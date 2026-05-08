import 'package:flutter/material.dart';

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
          child: FilledButton(
            onPressed: enabled ? onLong : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff00b884),
              minimumSize: const Size.fromHeight(64),
            ),
            child: const Text('LONG'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: enabled ? onShort : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdf3d55),
              minimumSize: const Size.fromHeight(64),
            ),
            child: const Text('SHORT'),
          ),
        ),
      ],
    );
  }
}
