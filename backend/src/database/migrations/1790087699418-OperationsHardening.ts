import { MigrationInterface, QueryRunner } from 'typeorm';

/** Additive production features. The migration never rewrites financial rows. */
export class OperationsHardening1790087699418 implements MigrationInterface {
  name = 'OperationsHardening1790087699418';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."collections_status_enum" ADD VALUE IF NOT EXISTS 'reversed'`,
    );
    await queryRunner.query(
      `ALTER TYPE "public"."ledger_entries_category_enum" ADD VALUE IF NOT EXISTS 'reconciliation'`,
    );
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "public"."inventory_stock_movements_type_enum"
          AS ENUM('opening', 'stock_in', 'sale', 'reversal');
      EXCEPTION WHEN duplicate_object THEN null; END $$
    `);

    await queryRunner.query(
      `ALTER TABLE "ledger_entries" ADD COLUMN IF NOT EXISTS "reverses_entry_id" uuid`,
    );
    await queryRunner.query(
      `ALTER TABLE "ledger_entries" ADD COLUMN IF NOT EXISTS "metadata" jsonb`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "IDX_ledger_one_reversal" ON "ledger_entries" ("reverses_entry_id") WHERE "reverses_entry_id" IS NOT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "ledger_entries" DROP CONSTRAINT IF EXISTS "FK_ledger_reverses_entry"`,
    );
    await queryRunner.query(
      `ALTER TABLE "ledger_entries" ADD CONSTRAINT "FK_ledger_reverses_entry" FOREIGN KEY ("reverses_entry_id") REFERENCES "ledger_entries"("id") ON DELETE RESTRICT`,
    );

    await queryRunner.query(
      `ALTER TABLE "collections" ADD COLUMN IF NOT EXISTS "reversed_at" timestamptz`,
    );
    await queryRunner.query(
      `ALTER TABLE "collections" ADD COLUMN IF NOT EXISTS "reversal_reason" varchar(300)`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_products" ADD COLUMN IF NOT EXISTS "cost_price" numeric(16,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_sales" ADD COLUMN IF NOT EXISTS "unit_cost" numeric(16,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_sales" ADD COLUMN IF NOT EXISTS "gross_profit" numeric(16,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_sales" ADD COLUMN IF NOT EXISTS "reversed_at" timestamptz`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_sales" ADD COLUMN IF NOT EXISTS "reversal_reason" varchar(300)`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "daily_closes" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "business_date" date NOT NULL,
        "snapshot" jsonb NOT NULL,
        "total_assets" numeric(16,2) NOT NULL,
        "pending_collections" numeric(16,2) NOT NULL,
        "closed_by" varchar(80) NOT NULL,
        "note" varchar(300),
        "closed_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_daily_closes" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_daily_closes_business_date" UNIQUE ("business_date")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "inventory_stock_movements" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "product_id" uuid NOT NULL,
        "type" "public"."inventory_stock_movements_type_enum" NOT NULL,
        "quantity" integer NOT NULL,
        "unit_cost" numeric(16,2) NOT NULL DEFAULT 0,
        "supplier" varchar(150),
        "note" varchar(300),
        "performed_by" varchar(80) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_stock_movements" PRIMARY KEY ("id"),
        CONSTRAINT "FK_inventory_stock_product" FOREIGN KEY ("product_id")
          REFERENCES "inventory_products"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_stock_product_created" ON "inventory_stock_movements" ("product_id", "created_at")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "inventory_stock_movements"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "daily_closes"`);
    await queryRunner.query(
      `DROP INDEX IF EXISTS "public"."IDX_ledger_one_reversal"`,
    );
    await queryRunner.query(
      `ALTER TABLE "ledger_entries" DROP CONSTRAINT IF EXISTS "FK_ledger_reverses_entry"`,
    );
    for (const [table, column] of [
      ['inventory_sales', 'reversal_reason'],
      ['inventory_sales', 'reversed_at'],
      ['inventory_sales', 'gross_profit'],
      ['inventory_sales', 'unit_cost'],
      ['inventory_products', 'cost_price'],
      ['collections', 'reversal_reason'],
      ['collections', 'reversed_at'],
      ['ledger_entries', 'metadata'],
      ['ledger_entries', 'reverses_entry_id'],
    ]) {
      await queryRunner.query(
        `ALTER TABLE "${table}" DROP COLUMN IF EXISTS "${column}"`,
      );
    }
    await queryRunner.query(
      `DROP TYPE IF EXISTS "public"."inventory_stock_movements_type_enum"`,
    );
    // PostgreSQL enum values are intentionally retained; removing them can
    // invalidate historical rows and is not a safe rollback operation.
  }
}
