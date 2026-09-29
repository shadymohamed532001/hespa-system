import { MigrationInterface, QueryRunner } from 'typeorm';

export class PurchaseVisa1790087699433 implements MigrationInterface {
  name = 'PurchaseVisa1790087699433';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."ledger_entries_category_enum" ADD VALUE IF NOT EXISTS 'purchase_visa_usage'`,
    );
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "purchase_visas" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" character varying(150) NOT NULL,
        "active" boolean NOT NULL DEFAULT true,
        "balance" numeric(16,2) NOT NULL DEFAULT 0,
        "commission_balance" numeric(16,2) NOT NULL DEFAULT 0,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_purchase_visas" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_purchase_visas_name" UNIQUE ("name")
      )
    `);
  }

  public async down(): Promise<void> {
    // Keep the table and enum value so historical visa entries remain readable.
  }
}
