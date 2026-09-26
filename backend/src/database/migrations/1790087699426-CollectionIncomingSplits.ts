import { MigrationInterface, QueryRunner } from 'typeorm';

export class CollectionIncomingSplits1790087699426
  implements MigrationInterface
{
  name = 'CollectionIncomingSplits1790087699426';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "collections" ADD COLUMN IF NOT EXISTS "cash_amount" numeric(16,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "collections" ADD COLUMN IF NOT EXISTS "incoming_splits" jsonb`,
    );
    await queryRunner.query(
      `UPDATE "collections" SET "cash_amount" = "amount" WHERE "cash_amount" IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "collections" DROP COLUMN IF EXISTS "incoming_splits"`,
    );
    await queryRunner.query(
      `ALTER TABLE "collections" DROP COLUMN IF EXISTS "cash_amount"`,
    );
  }
}
