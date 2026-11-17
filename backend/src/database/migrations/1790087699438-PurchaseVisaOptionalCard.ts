import { MigrationInterface, QueryRunner } from 'typeorm';

/** Visas are registered by holder name and balance; card details are optional. */
export class PurchaseVisaOptionalCard1790087699438 implements MigrationInterface {
  name = 'PurchaseVisaOptionalCard1790087699438';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "purchase_visas"
        ALTER COLUMN "card_number" DROP NOT NULL,
        ALTER COLUMN "expires_on" DROP NOT NULL
    `);
  }

  public async down(): Promise<void> {
    // Visas created without card details cannot be made NOT NULL again.
  }
}
