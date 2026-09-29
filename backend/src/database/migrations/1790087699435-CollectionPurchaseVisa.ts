import { MigrationInterface, QueryRunner } from 'typeorm';

export class CollectionPurchaseVisa1790087699435 implements MigrationInterface {
  name = 'CollectionPurchaseVisa1790087699435';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "collections"
        ADD COLUMN IF NOT EXISTS "purchase_visa_id" uuid,
        ADD COLUMN IF NOT EXISTS "with_service" boolean
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        ALTER TABLE "collections"
          ADD CONSTRAINT "FK_collections_purchase_visa"
          FOREIGN KEY ("purchase_visa_id")
          REFERENCES "purchase_visas"("id")
          ON DELETE RESTRICT;
      EXCEPTION
        WHEN duplicate_object THEN NULL;
      END $$;
    `);
  }

  public async down(): Promise<void> {
    // Keep the link so past receipts still show which visa was used.
  }
}
