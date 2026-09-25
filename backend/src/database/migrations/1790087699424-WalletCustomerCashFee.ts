import { MigrationInterface, QueryRunner } from 'typeorm';

export class WalletCustomerCashFee1790087699424 implements MigrationInterface {
  name = 'WalletCustomerCashFee1790087699424';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."ledger_entries_category_enum" ADD VALUE IF NOT EXISTS 'wallet_cash_fee'`,
    );
  }

  public async down(): Promise<void> {
    // Keep enum values so historical financial entries remain readable.
  }
}
