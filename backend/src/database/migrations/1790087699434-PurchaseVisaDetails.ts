import { MigrationInterface, QueryRunner } from 'typeorm';

export class PurchaseVisaDetails1790087699434 implements MigrationInterface {
  name = 'PurchaseVisaDetails1790087699434';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "purchase_visas"
        ADD COLUMN IF NOT EXISTS "card_number" character varying(16),
        ADD COLUMN IF NOT EXISTS "owner_name" character varying(120),
        ADD COLUMN IF NOT EXISTS "expires_on" date
    `);
    await queryRunner.query(`
      ALTER TABLE "purchase_visas"
        ALTER COLUMN "card_number" SET NOT NULL,
        ALTER COLUMN "owner_name" SET NOT NULL,
        ALTER COLUMN "expires_on" SET NOT NULL
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "UQ_purchase_visas_card_number"
      ON "purchase_visas" ("card_number")
    `);
  }

  public async down(): Promise<void> {
    // Keep card details so registered visas stay readable.
  }
}
