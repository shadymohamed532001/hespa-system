import { MigrationInterface, QueryRunner } from 'typeorm';

export class FawryDailyDrop1790087699425 implements MigrationInterface {
  name = 'FawryDailyDrop1790087699425';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "notifications" ADD COLUMN IF NOT EXISTS "admin_only" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "notifications" ADD COLUMN IF NOT EXISTS "dedupe_key" character varying(120)`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_notifications_dedupe_key" ON "notifications" ("dedupe_key")`,
    );
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "fawry_daily_drops" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "account_id" uuid NOT NULL,
        "business_date" date NOT NULL,
        "amount" numeric(16,2) NOT NULL,
        "performed_by" character varying(80) NOT NULL,
        "ledger_entry_id" uuid,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_fawry_daily_drops" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_fawry_daily_drops_account_date" UNIQUE ("account_id", "business_date"),
        CONSTRAINT "FK_fawry_daily_drops_account" FOREIGN KEY ("account_id") REFERENCES "financial_accounts"("id") ON DELETE RESTRICT
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "fawry_daily_drops"`);
    await queryRunner.query(
      `DROP INDEX IF EXISTS "UQ_notifications_dedupe_key"`,
    );
    await queryRunner.query(
      `ALTER TABLE "notifications" DROP COLUMN IF EXISTS "dedupe_key"`,
    );
    await queryRunner.query(
      `ALTER TABLE "notifications" DROP COLUMN IF EXISTS "admin_only"`,
    );
  }
}
