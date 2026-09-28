import 'package:flutter_test/flutter_test.dart';
import 'package:hesba_desktop/features/accounts/profit_qr_commission.dart';

void main() {
  test('QR cash-out uses the cash amount as the fee base', () {
    final result = profitQrCashOutBreakdown(1000)!;
    expect(result.customerTransferAmount, 1010);
    expect(result.customerCommission, 10);
    expect(result.providerIncomingFee, 2);
    expect(result.creditedAmount, 1008);
    expect(result.netCommissionBeforeSettlement, 8);
    expect(result.providerOutgoingFee, 4);
    expect(result.finalNetCommission, 4);
  });

  test('QR rates remain proportional above one thousand', () {
    final result = profitQrCashOutBreakdown(1500)!;
    expect(result.customerTransferAmount, 1515);
    expect(result.providerIncomingFee, 3);
    expect(result.creditedAmount, 1512);
    expect(result.finalNetCommission, 6);
  });

  test('QR rates round to the nearest piaster', () {
    final result = profitQrCashOutBreakdown(1234.56)!;
    expect(result.customerCommission, 12.35);
    expect(result.providerIncomingFee, 2.47);
    expect(result.providerOutgoingFee, 4.94);
  });
}
