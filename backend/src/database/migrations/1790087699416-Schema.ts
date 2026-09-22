import { MigrationInterface, QueryRunner, TableColumn } from 'typeorm';

export class Schema1790087699416 implements MigrationInterface {
  name = 'Schema1790087699416';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    // Existing installations were originally managed by synchronize=true.
    // Bring them onto the migration track without recreating or deleting data.
    if (await queryRunner.hasTable('users')) {
      if (!(await queryRunner.hasColumn('users', 'token_version'))) {
        await queryRunner.addColumn(
          'users',
          new TableColumn({ name: 'token_version', type: 'int', default: 0 }),
        );
      }
      for (const column of ['source_type', 'target_type']) {
        if (!(await queryRunner.hasColumn('ledger_entries', column))) {
          await queryRunner.addColumn(
            'ledger_entries',
            new TableColumn({
              name: column,
              type: 'varchar',
              length: '50',
              isNullable: true,
            }),
          );
        }
      }
      for (const column of ['source_id', 'target_id']) {
        if (!(await queryRunner.hasColumn('ledger_entries', column))) {
          await queryRunner.addColumn(
            'ledger_entries',
            new TableColumn({
              name: column,
              type: 'varchar',
              length: '80',
              isNullable: true,
            }),
          );
        }
      }
      await queryRunner.query(
        `CREATE TABLE IF NOT EXISTS "audit_events" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid, "username" character varying(80), "method" character varying(12) NOT NULL, "path" character varying(300) NOT NULL, "status_code" integer NOT NULL, "success" boolean NOT NULL DEFAULT true, "ip_address" character varying(80), "user_agent" character varying(500), "details" jsonb, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_910f64d901a5c3e9878f0d4a407" PRIMARY KEY ("id"))`,
      );
      await queryRunner.query(
        `CREATE INDEX IF NOT EXISTS "IDX_497bb4f7c4c55db9749616cd2a" ON "audit_events" ("created_at")`,
      );
      await queryRunner.query(
        `DO $$ BEGIN CREATE TYPE "public"."idempotency_records_status_enum" AS ENUM('pending', 'completed'); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
      );
      await queryRunner.query(
        `CREATE TABLE IF NOT EXISTS "idempotency_records" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "key" character varying(120) NOT NULL, "method" character varying(12) NOT NULL, "path" character varying(300) NOT NULL, "request_hash" character varying(64) NOT NULL, "status" "public"."idempotency_records_status_enum" NOT NULL DEFAULT 'pending', "response" jsonb, "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_9ae4e93699362b0d4e3da3dd1c2" PRIMARY KEY ("id"))`,
      );
      await queryRunner.query(
        `CREATE UNIQUE INDEX IF NOT EXISTS "IDX_361095756bf434c1971a5a89be" ON "idempotency_records" ("user_id", "key")`,
      );
      return;
    }

    await queryRunner.query(
      `CREATE TYPE "public"."financial_accounts_type_enum" AS ENUM('fawry', 'company', 'operating')`,
    );
    await queryRunner.query(
      `CREATE TABLE "financial_accounts" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying(150) NOT NULL, "type" "public"."financial_accounts_type_enum" NOT NULL, "active" boolean NOT NULL DEFAULT true, "opening_balance" numeric(16,2) NOT NULL DEFAULT '0', "today_top_up" numeric(16,2) NOT NULL DEFAULT '0', "balance" numeric(16,2) NOT NULL DEFAULT '0', "commission_balance" numeric(16,2) NOT NULL DEFAULT '0', "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_1c049fd216017ee8afd92ece66d" UNIQUE ("name"), CONSTRAINT "PK_e684ee5a80dfa62dfe64dd959d9" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."collections_executionmode_enum" AS ENUM('immediate', 'hold')`,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."collections_status_enum" AS ENUM('pending', 'done')`,
    );
    await queryRunner.query(
      `CREATE TABLE "collections" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "reference" character varying(40) NOT NULL, "agent_name" character varying(150) NOT NULL, "company_name" character varying(150) NOT NULL, "amount" numeric(16,2) NOT NULL, "executionMode" "public"."collections_executionmode_enum" NOT NULL, "status" "public"."collections_status_enum" NOT NULL, "received_at" TIMESTAMP WITH TIME ZONE NOT NULL, "executed_at" TIMESTAMP WITH TIME ZONE, "commission" numeric(16,2) NOT NULL DEFAULT '0', "created_at" TIMESTAMP NOT NULL DEFAULT now(), "account_id" uuid, CONSTRAINT "UQ_f2acf3e2a223189eddd4bccc914" UNIQUE ("reference"), CONSTRAINT "PK_21c00b1ebbd41ba1354242c5c4e" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "audit_events" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid, "username" character varying(80), "method" character varying(12) NOT NULL, "path" character varying(300) NOT NULL, "status_code" integer NOT NULL, "success" boolean NOT NULL DEFAULT true, "ip_address" character varying(80), "user_agent" character varying(500), "details" jsonb, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_910f64d901a5c3e9878f0d4a407" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_497bb4f7c4c55db9749616cd2a" ON "audit_events"  ("created_at") `,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."inventory_products_category_enum" AS ENUM('mobile', 'accessory', 'case', 'screen', 'other')`,
    );
    await queryRunner.query(
      `CREATE TABLE "inventory_products" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying(150) NOT NULL, "category" "public"."inventory_products_category_enum" NOT NULL, "stock_qty" integer NOT NULL DEFAULT '0', "sold_qty" integer NOT NULL DEFAULT '0', "default_price" numeric(16,2) NOT NULL DEFAULT '0', "active" boolean NOT NULL DEFAULT true, "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_f0025e3643d268bfda5f6cf9028" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "inventory_sales" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "product_id" uuid NOT NULL, "quantity" integer NOT NULL, "unit_price" numeric(16,2) NOT NULL, "total_amount" numeric(16,2) NOT NULL, "note" character varying(200), "performed_by" character varying(80) NOT NULL, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_66e63c1e64382c7ccea0712f2ea" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "inventory_treasury" ("id" character varying NOT NULL DEFAULT 'inventory', "balance" numeric(16,2) NOT NULL DEFAULT '0', "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_77249cc0f526f44316e18081d02" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."idempotency_records_status_enum" AS ENUM('pending', 'completed')`,
    );
    await queryRunner.query(
      `CREATE TABLE "idempotency_records" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "key" character varying(120) NOT NULL, "method" character varying(12) NOT NULL, "path" character varying(300) NOT NULL, "request_hash" character varying(64) NOT NULL, "status" "public"."idempotency_records_status_enum" NOT NULL DEFAULT 'pending', "response" jsonb, "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_9ae4e93699362b0d4e3da3dd1c2" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "IDX_361095756bf434c1971a5a89be" ON "idempotency_records"  ("user_id", "key") `,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."ledger_entries_category_enum" AS ENUM('opening_balance', 'top_up', 'internal_transfer', 'cash_receipt', 'company_execution', 'commission', 'machine_usage', 'daily_rollover', 'reversal')`,
    );
    await queryRunner.query(
      `CREATE TABLE "ledger_entries" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "category" "public"."ledger_entries_category_enum" NOT NULL, "amount" numeric(16,2) NOT NULL, "entity_type" character varying(50) NOT NULL, "entity_id" character varying(80), "reference" character varying(80), "description" text NOT NULL, "performed_by" character varying(80) NOT NULL, "source_type" character varying(50), "source_id" character varying(80), "target_type" character varying(50), "target_id" character varying(80), "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6efcb84411d3f08b08450ae75d5" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "machines" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying(150) NOT NULL, "active" boolean NOT NULL DEFAULT true, "loaded_balance" numeric(16,2) NOT NULL DEFAULT '0', "used_balance" numeric(16,2) NOT NULL DEFAULT '0', "commission_balance" numeric(16,2) NOT NULL DEFAULT '0', "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_005481cad20f051f1ea2126bc01" UNIQUE ("name"), CONSTRAINT "PK_7b0817c674bb984650c5274e713" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."notifications_kind_enum" AS ENUM('deposit', 'withdrawal', 'transfer', 'info')`,
    );
    await queryRunner.query(
      `CREATE TABLE "notifications" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "kind" "public"."notifications_kind_enum" NOT NULL, "title" character varying(120) NOT NULL, "body" text NOT NULL, "amount" numeric(16,2), "ledger_entry_id" uuid, "is_read" boolean NOT NULL DEFAULT false, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_2e8bb00a09c6e4e050f8297519f" UNIQUE ("ledger_entry_id"), CONSTRAINT "PK_6a72c3c0f683f6462415e653c3a" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "treasury" ("id" character varying NOT NULL DEFAULT 'main', "balance" numeric(16,2) NOT NULL DEFAULT '0', "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_55655557260341eb45eb7306810" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TYPE "public"."users_role_enum" AS ENUM('admin', 'employee')`,
    );
    await queryRunner.query(
      `CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "username" character varying(80) NOT NULL, "display_name" character varying(120) NOT NULL DEFAULT '', "password_hash" character varying NOT NULL, "role" "public"."users_role_enum" NOT NULL, "permissions" jsonb NOT NULL DEFAULT '["view_balances","receive_collections","sell_inventory","use_machines"]', "limits" jsonb NOT NULL DEFAULT '{"maxReceiveAmount":null,"maxTopUpAmount":null,"maxSaleAmount":null,"maxTransferAmount":null}', "active" boolean NOT NULL DEFAULT true, "token_version" integer NOT NULL DEFAULT '0', "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_fe0bb3f6520ee0469504521e710" UNIQUE ("username"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "wallets" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying(150) NOT NULL, "type" character varying(80) NOT NULL, "active" boolean NOT NULL DEFAULT true, "opening_balance" numeric(16,2) NOT NULL DEFAULT '0', "today_top_up" numeric(16,2) NOT NULL DEFAULT '0', "balance" numeric(16,2) NOT NULL DEFAULT '0', "daily_top_up" numeric(16,2) NOT NULL DEFAULT '0', "monthly_top_up" numeric(16,2) NOT NULL DEFAULT '0', "counter_day" date, "counter_month" character varying(7), "commission_balance" numeric(16,2) NOT NULL DEFAULT '0', "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_acadc3471255d63d92f137ca2c7" UNIQUE ("name"), CONSTRAINT "PK_8402e5df5a30a229380e83e4f7e" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `ALTER TABLE "collections" ADD CONSTRAINT "FK_741399e4a3d157fddd26d2a4600" FOREIGN KEY ("account_id") REFERENCES "financial_accounts"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_sales" ADD CONSTRAINT "FK_51aa2c84b06b47ff586ec9158f8" FOREIGN KEY ("product_id") REFERENCES "inventory_products"("id") ON DELETE RESTRICT ON UPDATE NO ACTION`,
    );
    await queryRunner.query(
      `CREATE TABLE "_hesba_initial_schema_marker" ("id" integer PRIMARY KEY)`,
    );
    await queryRunner.query(
      `INSERT INTO "_hesba_initial_schema_marker" ("id") VALUES (1)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    if (!(await queryRunner.hasTable('_hesba_initial_schema_marker'))) return;
    await queryRunner.query(`DROP TABLE "_hesba_initial_schema_marker"`);
    await queryRunner.query(
      `ALTER TABLE "inventory_sales" DROP CONSTRAINT "FK_51aa2c84b06b47ff586ec9158f8"`,
    );
    await queryRunner.query(
      `ALTER TABLE "collections" DROP CONSTRAINT "FK_741399e4a3d157fddd26d2a4600"`,
    );
    await queryRunner.query(`DROP TABLE "wallets"`);
    await queryRunner.query(`DROP TABLE "users"`);
    await queryRunner.query(`DROP TYPE "public"."users_role_enum"`);
    await queryRunner.query(`DROP TABLE "treasury"`);
    await queryRunner.query(`DROP TABLE "notifications"`);
    await queryRunner.query(`DROP TYPE "public"."notifications_kind_enum"`);
    await queryRunner.query(`DROP TABLE "machines"`);
    await queryRunner.query(`DROP TABLE "ledger_entries"`);
    await queryRunner.query(
      `DROP TYPE "public"."ledger_entries_category_enum"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_361095756bf434c1971a5a89be"`,
    );
    await queryRunner.query(`DROP TABLE "idempotency_records"`);
    await queryRunner.query(
      `DROP TYPE "public"."idempotency_records_status_enum"`,
    );
    await queryRunner.query(`DROP TABLE "inventory_treasury"`);
    await queryRunner.query(`DROP TABLE "inventory_sales"`);
    await queryRunner.query(`DROP TABLE "inventory_products"`);
    await queryRunner.query(
      `DROP TYPE "public"."inventory_products_category_enum"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_497bb4f7c4c55db9749616cd2a"`,
    );
    await queryRunner.query(`DROP TABLE "audit_events"`);
    await queryRunner.query(`DROP TABLE "collections"`);
    await queryRunner.query(`DROP TYPE "public"."collections_status_enum"`);
    await queryRunner.query(
      `DROP TYPE "public"."collections_executionmode_enum"`,
    );
    await queryRunner.query(`DROP TABLE "financial_accounts"`);
    await queryRunner.query(
      `DROP TYPE "public"."financial_accounts_type_enum"`,
    );
  }
}
