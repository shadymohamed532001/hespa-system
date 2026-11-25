import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Fawry's 5,000,000 limit caps what is withdrawn per day, not the balance.
 * Each account keeps a lazily rolled daily counter.
 */
export class FawryDailyWithdrawLimit1790087699441 implements MigrationInterface {
  name = 'FawryDailyWithdrawLimit1790087699441';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "financial_accounts" ADD COLUMN IF NOT EXISTS "daily_withdrawn" numeric(16,2) NOT NULL DEFAULT '0'`,
    );
    await queryRunner.query(
      `ALTER TABLE "financial_accounts" ADD COLUMN IF NOT EXISTS "withdraw_counter_day" date`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "financial_accounts" DROP COLUMN IF EXISTS "withdraw_counter_day"`,
    );
    await queryRunner.query(
      `ALTER TABLE "financial_accounts" DROP COLUMN IF EXISTS "daily_withdrawn"`,
    );
  }
}
