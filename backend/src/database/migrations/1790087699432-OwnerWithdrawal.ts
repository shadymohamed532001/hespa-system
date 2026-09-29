import { MigrationInterface, QueryRunner } from 'typeorm';

export class OwnerWithdrawal1790087699432 implements MigrationInterface {
  name = 'OwnerWithdrawal1790087699432';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."ledger_entries_category_enum" ADD VALUE IF NOT EXISTS 'owner_withdrawal'`,
    );
  }

  public async down(): Promise<void> {
    // Keep enum values so historical financial entries remain readable.
  }
}
