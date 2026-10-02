import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/core/utils/money_formatter.dart';
import 'package:hesba_desktop/features/collections/profit_collection_commission.dart';
import 'package:hesba_desktop/features/accounts/profit_qr_commission.dart';

void main() {
  test('QR customer fees use the 500 and 1000 tiers', () {
    for (final amount in [1, 499.99, 500, 500.01, 800, 1000]) {
      final result = profitQrCashOutBreakdown(amount, commissionInCash: true)!;
      expect(result.customerCommission, amount <= 500 ? 5 : 10);
      expect(result.cashAmount, amount);
    }
    final deducted = profitQrCashOutBreakdown(800)!;
    expect(deducted.cashAmount, 790);
    expect(deducted.creditedAmount, 798.4);
    expect(deducted.providerIncomingFee, 1.6);
  });

  test(
    '20000 transfer credits 19960 to QR with the commission in treasury',
    () {
      for (final cash in [false, true]) {
        final result = profitQrCashOutBreakdown(20000, commissionInCash: cash)!;
        expect(result.customerTransferAmount, 20000);
        expect(result.customerCommission, 200);
        expect(result.providerIncomingFee, 40);
        expect(result.creditedAmount, 19960);
        expect(result.cashAmount, cash ? 20000 : 19800);
      }
    },
  );

  test(
    'fractional money is displayed and collection fees preserve piasters',
    () {
      expect(money(1234.56), '1,234.56 ج.م');
      expect(money(0.01), '0.01 ج.م');
      expect(profitCollectionCommission(1234.56), 4.94);
      expect(purchaseVisaCollectionProfit(1234.56, true), 16.05);
    },
  );

  test('QR cash-out uses the cash amount as the fee base', () {
    final result = profitQrCashOutBreakdown(1000)!;
    expect(result.customerTransferAmount, 1000);
    expect(result.customerCommission, 10);
    expect(result.providerIncomingFee, 2);
    expect(result.creditedAmount, 998);
    expect(result.netCommissionBeforeSettlement, 8);
    expect(result.providerOutgoingFee, 4);
    expect(result.finalNetCommission, 4);
  });

  test('QR rates remain proportional above one thousand', () {
    final result = profitQrCashOutBreakdown(1500)!;
    expect(result.customerTransferAmount, 1500);
    expect(result.providerIncomingFee, 3);
    expect(result.creditedAmount, 1497);
    expect(result.finalNetCommission, 6);
  });

  test('QR rates round to the nearest piaster', () {
    final result = profitQrCashOutBreakdown(1234.56)!;
    expect(result.customerCommission, 12.35);
    expect(result.providerIncomingFee, 2.47);
    expect(result.providerOutgoingFee, 4.94);
    expect(result.customerTransferAmount, 1234.56);
    expect(result.creditedAmount, 1232.09);
    expect(result.netCommissionBeforeSettlement, 9.88);
  });
}
