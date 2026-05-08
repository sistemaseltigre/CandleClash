import 'package:flutter/material.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & Session')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session authority signs start_round and settle_round while active.'),
            SizedBox(height: 12),
            Text('Remaining spend limit and expiration timer will read PlayerSession once IDL decoding is wired.'),
            SizedBox(height: 12),
            Text('Deposit and withdraw use PlayerVault PDA and require wallet approval.'),
          ],
        ),
      ),
    );
  }
}
