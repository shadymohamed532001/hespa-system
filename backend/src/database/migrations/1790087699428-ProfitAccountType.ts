import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProfitAccountType1790087699428 implements MigrationInterface {
  name = 'ProfitAccountType1790087699428';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."financial_accounts_type_enum" ADD VALUE IF NOT EXISTS 'profit'`,
    );
  }

  public async down(): Promise<void> {
    // PostgreSQL cannot drop a single enum value while rows may still use it.
  }
}
