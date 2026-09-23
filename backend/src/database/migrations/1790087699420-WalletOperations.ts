import { MigrationInterface, QueryRunner } from 'typeorm';

export class WalletOperations1790087699420 implements MigrationInterface {
  name = 'WalletOperations1790087699420';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."ledger_entries_category_enum" ADD VALUE IF NOT EXISTS 'wallet_usage'`,
    );
  }

  public async down(): Promise<void> {
    // PostgreSQL enum values are retained to keep historical ledger rows valid.
  }
}
