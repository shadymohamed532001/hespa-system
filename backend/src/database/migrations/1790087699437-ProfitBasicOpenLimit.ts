import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProfitBasicOpenLimit1790087699437 implements MigrationInterface {
  name = 'ProfitBasicOpenLimit1790087699437';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE financial_accounts
      ADD COLUMN IF NOT EXISTS open_limit boolean NOT NULL DEFAULT false
    `);
    await queryRunner.query(`
      UPDATE financial_accounts
      SET open_limit = true
      WHERE type = 'profit'
        AND (
          replace(replace(replace(replace(name, ' ', ''), 'أ', 'ا'), 'إ', 'ا'), 'آ', 'ا')
            LIKE '%اساسي%'
        )
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE financial_accounts DROP COLUMN IF EXISTS open_limit`,
    );
  }
}
