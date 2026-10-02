import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/features/wallets/wallet_commission.dart';

void main() {
  test('customer wallet fees follow receive tiers across thousands', () {
    for (final (amount, fee) in <(num, int)>[
      (200, 5),
      (500, 10),
      (1000, 20),
      (1001, 25),
      (1200, 25),
      (1500, 30),
      (2000, 40),
    ]) {
      expect(
        customerWalletCommission(
          type: 'vodafone_cash',
          direction: 'receive',
          amount: amount,
        ),
        fee,
      );
    }
  });

  test('customer wallet send fees are ten per thousand', () {
    expect(
      customerWalletCommission(
        type: 'orange_cash',
        direction: 'send',
        amount: 200,
      ),
      5,
    );
    expect(
      customerWalletCommission(
        type: 'orange_cash',
        direction: 'send',
        amount: 2000,
      ),
      20,
    );
  });

  test(
    'InstaPay charges five below 1000 then ten per thousand in both directions',
    () {
      for (final direction in ['send', 'receive']) {
        expect(
          customerWalletCommission(
            type: 'instapay',
            direction: direction,
            amount: 999.99,
          ),
          5,
        );
        expect(
          customerWalletCommission(
            type: 'instapay',
            direction: direction,
            amount: 1000,
          ),
          10,
        );
        expect(
          customerWalletCommission(
            type: 'instapay',
            direction: direction,
            amount: 1500,
          ),
          15,
        );
        expect(
          customerWalletCommission(
            type: 'instapay',
            direction: direction,
            amount: 1234.56,
          ),
          12.35,
        );
        expect(
          customerWalletCommission(
            type: 'instapay',
            direction: direction,
            amount: 5000,
          ),
          50,
        );
      }
    },
  );
}
