import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Idempotent bridge for databases that were created by synchronize=true before
 * migrations were introduced. It is intentionally additive: financial data is
 * never dropped or rewritten and it is safe to run after the full base schema.
 */
export class LegacySchemaRepair1790087699417 implements MigrationInterface {
  name = 'LegacySchemaRepair1790087699417';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);

    const enumTypes: Array<[string, string[]]> = [
      ['financial_accounts_type_enum', ['fawry', 'company', 'operating']],
      ['collections_executionmode_enum', ['immediate', 'hold']],
      ['collections_status_enum', ['pending', 'done']],
      [
        'inventory_products_category_enum',
        ['mobile', 'accessory', 'case', 'screen', 'other'],
      ],
      ['idempotency_records_status_enum', ['pending', 'completed']],
      [
        'ledger_entries_category_enum',
        [
          'opening_balance',
          'top_up',
          'internal_transfer',
          'cash_receipt',
          'company_execution',
          'commission',
          'machine_usage',
          'daily_rollover',
          'reversal',
        ],
      ],
      [
        'notifications_kind_enum',
        ['deposit', 'withdrawal', 'transfer', 'info'],
      ],
      ['users_role_enum', ['admin', 'employee']],
    ];
    for (const [type, values] of enumTypes) {
      const literals = values.map((value) => `'${value}'`).join(', ');
      await queryRunner.query(
        `DO $$ BEGIN CREATE TYPE "public"."${type}" AS ENUM(${literals}); EXCEPTION WHEN duplicate_object THEN null; END $$;`,
      );
      for (const value of values) {
        await queryRunner.query(
          `ALTER TYPE "public"."${type}" ADD VALUE IF NOT EXISTS '${value}'`,
        );
      }
    }

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "financial_accounts" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar(150) NOT NULL,
        "type" "public"."financial_accounts_type_enum" NOT NULL,
        "active" boolean NOT NULL DEFAULT true,
        "opening_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "today_top_up" numeric(16,2) NOT NULL DEFAULT 0,
        "balance" numeric(16,2) NOT NULL DEFAULT 0,
        "commission_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_financial_accounts_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "users" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "username" varchar(80) NOT NULL,
        "display_name" varchar(120) NOT NULL DEFAULT '',
        "password_hash" varchar NOT NULL,
        "role" "public"."users_role_enum" NOT NULL,
        "permissions" jsonb NOT NULL DEFAULT '["view_balances","receive_collections","sell_inventory","use_machines"]',
        "limits" jsonb NOT NULL DEFAULT '{"maxReceiveAmount":null,"maxTopUpAmount":null,"maxSaleAmount":null,"maxTransferAmount":null}',
        "active" boolean NOT NULL DEFAULT true,
        "token_version" integer NOT NULL DEFAULT 0,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_users_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "wallets" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar(150) NOT NULL,
        "type" varchar(80) NOT NULL,
        "active" boolean NOT NULL DEFAULT true,
        "opening_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "today_top_up" numeric(16,2) NOT NULL DEFAULT 0,
        "balance" numeric(16,2) NOT NULL DEFAULT 0,
        "daily_top_up" numeric(16,2) NOT NULL DEFAULT 0,
        "monthly_top_up" numeric(16,2) NOT NULL DEFAULT 0,
        "counter_day" date,
        "counter_month" varchar(7),
        "commission_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_wallets_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "machines" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar(150) NOT NULL,
        "active" boolean NOT NULL DEFAULT true,
        "loaded_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "used_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "commission_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_machines_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "treasury" (
        "id" varchar NOT NULL DEFAULT 'main',
        "balance" numeric(16,2) NOT NULL DEFAULT 0,
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_treasury_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "ledger_entries" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "category" "public"."ledger_entries_category_enum" NOT NULL,
        "amount" numeric(16,2) NOT NULL,
        "entity_type" varchar(50) NOT NULL,
        "entity_id" varchar(80),
        "reference" varchar(80),
        "description" text NOT NULL,
        "performed_by" varchar(80) NOT NULL,
        "source_type" varchar(50),
        "source_id" varchar(80),
        "target_type" varchar(50),
        "target_id" varchar(80),
        "created_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_ledger_entries_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "collections" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "reference" varchar(40) NOT NULL,
        "agent_name" varchar(150) NOT NULL,
        "company_name" varchar(150) NOT NULL,
        "amount" numeric(16,2) NOT NULL,
        "executionMode" "public"."collections_executionmode_enum" NOT NULL,
        "status" "public"."collections_status_enum" NOT NULL,
        "received_at" timestamptz NOT NULL,
        "executed_at" timestamptz,
        "commission" numeric(16,2) NOT NULL DEFAULT 0,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "account_id" uuid,
        CONSTRAINT "PK_collections_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "inventory_products" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar(150) NOT NULL,
        "category" "public"."inventory_products_category_enum" NOT NULL,
        "stock_qty" integer NOT NULL DEFAULT 0,
        "sold_qty" integer NOT NULL DEFAULT 0,
        "default_price" numeric(16,2) NOT NULL DEFAULT 0,
        "active" boolean NOT NULL DEFAULT true,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_products_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "inventory_sales" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "product_id" uuid NOT NULL,
        "quantity" integer NOT NULL,
        "unit_price" numeric(16,2) NOT NULL,
        "total_amount" numeric(16,2) NOT NULL,
        "note" varchar(200),
        "performed_by" varchar(80) NOT NULL,
        "created_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_sales_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "inventory_treasury" (
        "id" varchar NOT NULL DEFAULT 'inventory',
        "balance" numeric(16,2) NOT NULL DEFAULT 0,
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_inventory_treasury_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "notifications" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "kind" "public"."notifications_kind_enum" NOT NULL,
        "title" varchar(120) NOT NULL,
        "body" text NOT NULL,
        "amount" numeric(16,2),
        "ledger_entry_id" uuid,
        "is_read" boolean NOT NULL DEFAULT false,
        "created_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_notifications_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "audit_events" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid,
        "username" varchar(80),
        "method" varchar(12) NOT NULL,
        "path" varchar(300) NOT NULL,
        "status_code" integer NOT NULL,
        "success" boolean NOT NULL DEFAULT true,
        "ip_address" varchar(80),
        "user_agent" varchar(500),
        "details" jsonb,
        "created_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_audit_events_repair" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "idempotency_records" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "key" varchar(120) NOT NULL,
        "method" varchar(12) NOT NULL,
        "path" varchar(300) NOT NULL,
        "request_hash" varchar(64) NOT NULL,
        "status" "public"."idempotency_records_status_enum" NOT NULL DEFAULT 'pending',
        "response" jsonb,
        "created_at" timestamp NOT NULL DEFAULT now(),
        "updated_at" timestamp NOT NULL DEFAULT now(),
        CONSTRAINT "PK_idempotency_records_repair" PRIMARY KEY ("id")
      )
    `);

    const additions: Array<[string, string]> = [
      ['users', `"display_name" varchar(120) NOT NULL DEFAULT ''`],
      [
        'users',
        `"permissions" jsonb NOT NULL DEFAULT '["view_balances","receive_collections","sell_inventory","use_machines"]'`,
      ],
      [
        'users',
        `"limits" jsonb NOT NULL DEFAULT '{"maxReceiveAmount":null,"maxTopUpAmount":null,"maxSaleAmount":null,"maxTransferAmount":null}'`,
      ],
      ['users', `"token_version" integer NOT NULL DEFAULT 0`],
      ['ledger_entries', `"source_type" varchar(50)`],
      ['ledger_entries', `"source_id" varchar(80)`],
      ['ledger_entries', `"target_type" varchar(50)`],
      ['ledger_entries', `"target_id" varchar(80)`],
      ['wallets', `"daily_top_up" numeric(16,2) NOT NULL DEFAULT 0`],
      ['wallets', `"monthly_top_up" numeric(16,2) NOT NULL DEFAULT 0`],
      ['wallets', `"counter_day" date`],
      ['wallets', `"counter_month" varchar(7)`],
      ['wallets', `"commission_balance" numeric(16,2) NOT NULL DEFAULT 0`],
      ['machines', `"commission_balance" numeric(16,2) NOT NULL DEFAULT 0`],
    ];
    for (const [table, definition] of additions) {
      await queryRunner.query(
        `ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS ${definition}`,
      );
    }

    await queryRunner.query(
      `UPDATE "users" SET "display_name" = "username" WHERE "display_name" = ''`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_users_username_repair" ON "users" ("username")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_accounts_name_repair" ON "financial_accounts" ("name")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_wallets_name_repair" ON "wallets" ("name")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_machines_name_repair" ON "machines" ("name")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_collections_reference_repair" ON "collections" ("reference")`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_notifications_ledger_repair" ON "notifications" ("ledger_entry_id") WHERE "ledger_entry_id" IS NOT NULL`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "UQ_idempotency_user_key_repair" ON "idempotency_records" ("user_id", "key")`,
    );

    // High-volume read paths used by the ledger, reports and pending summary.
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_ledger_created_at_repair" ON "ledger_entries" ("created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_ledger_entity_repair" ON "ledger_entries" ("entity_type", "entity_id", "created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_collections_status_repair" ON "collections" ("status")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_collections_received_repair" ON "collections" ("received_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_sales_created_repair" ON "inventory_sales" ("created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_audit_created_repair" ON "audit_events" ("created_at" DESC)`,
    );

    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname IN ('FK_collections_account_repair', 'FK_741399e4a3d157fddd26d2a4600')
        ) THEN
          ALTER TABLE "collections" ADD CONSTRAINT "FK_collections_account_repair"
          FOREIGN KEY ("account_id") REFERENCES "financial_accounts"("id") ON DELETE RESTRICT;
        END IF;
      END $$
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname IN ('FK_inventory_sale_product_repair', 'FK_51aa2c84b06b47ff586ec9158f8')
        ) THEN
          ALTER TABLE "inventory_sales" ADD CONSTRAINT "FK_inventory_sale_product_repair"
          FOREIGN KEY ("product_id") REFERENCES "inventory_products"("id") ON DELETE RESTRICT;
        END IF;
      END $$
    `);
  }

  public async down(): Promise<void> {
    // Deliberately non-destructive: this migration may have adopted tables and
    // columns containing legacy financial data that it did not create.
  }
}
