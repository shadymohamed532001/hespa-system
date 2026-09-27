import { MigrationInterface, QueryRunner } from 'typeorm';

export class FawryDeposits1790087699427 implements MigrationInterface {
  name = 'FawryDeposits1790087699427';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "fawry_deposits" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "account_id" uuid NOT NULL,
        "depositor_user_id" uuid,
        "depositor_name" character varying(120) NOT NULL,
        "cash_counts" jsonb NOT NULL,
        "amount" numeric(16,2) NOT NULL,
        "reference" character varying(80),
        "performed_by" character varying(80) NOT NULL,
        "ledger_entry_id" uuid,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_fawry_deposits" PRIMARY KEY ("id"),
        CONSTRAINT "FK_fawry_deposits_account" FOREIGN KEY ("account_id") REFERENCES "financial_accounts"("id") ON DELETE RESTRICT,
        CONSTRAINT "FK_fawry_deposits_depositor" FOREIGN KEY ("depositor_user_id") REFERENCES "users"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_fawry_deposits_ledger" FOREIGN KEY ("ledger_entry_id") REFERENCES "ledger_entries"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_fawry_deposits_account_created" ON "fawry_deposits" ("account_id", "created_at")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_fawry_deposits_depositor" ON "fawry_deposits" ("depositor_user_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "fawry_deposits"`);
  }
}
