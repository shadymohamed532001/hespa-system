import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProfitQrAccountType1790087699429 implements MigrationInterface {
  name = 'ProfitQrAccountType1790087699429';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."financial_accounts_type_enum" ADD VALUE IF NOT EXISTS 'profit_qr'`,
    );
  }

  public async down(): Promise<void> {
    // PostgreSQL cannot drop a single enum value while rows may still use it.
  }
}
