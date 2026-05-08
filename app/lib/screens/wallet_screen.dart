import 'package:flutter/material.dart';

import 'widgets/clash_widgets.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Row(
              children: [
                ClashLogo(height: 58),
                Spacer(),
                Icon(Icons.account_balance_wallet, color: clashGreen),
              ],
            ),
            const SizedBox(height: 16),
            ClashPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WALLET', style: TextStyle(color: clashGreen, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                  const SizedBox(height: 18),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.token, size: 48, color: clashPurple),
                        SizedBox(height: 8),
                        Text('TOTAL BALANCE', style: TextStyle(color: Colors.white54, letterSpacing: 1.2)),
                        SizedBox(height: 4),
                        Text('-- SOL', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {},
                          style: FilledButton.styleFrom(backgroundColor: clashGreen, foregroundColor: Colors.black),
                          child: const Text('DEPOSIT'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('WITHDRAW'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const ClashPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SESSION', style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
                  SizedBox(height: 10),
                  Text('Session authority signs start_round and settle_round while active.'),
                  SizedBox(height: 8),
                  Text('Remaining spend limit and expiration timer will read PlayerSession once IDL decoding is wired.'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClashBottomNav(current: 'wallet'),
    );
  }
}
