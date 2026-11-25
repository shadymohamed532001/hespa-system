import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Regular profit accounts are retired: QR profit accounts now take their
 * top-ups. Existing ones are deactivated (not deleted) so their history and
 * reports stay intact.
 */
export class RetireRegularProfit1790087699440 implements MigrationInterface {
  name = 'RetireRegularProfit1790087699440';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `UPDATE "financial_accounts" SET "active" = false WHERE "type" = 'profit'`,
    );
  }

  public async down(): Promise<void> {
    // Which accounts were active before is not recorded; reactivating is a
    // manual decision.
  }
}
