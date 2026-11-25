import { MigrationInterface, QueryRunner } from 'typeorm';

/** Record-only log of money the shop owner borrowed from people and repaid. */
export class ShopDebts1790087699439 implements MigrationInterface {
  name = 'ShopDebts1790087699439';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "shop_debt_movements" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "reference" character varying(40) NOT NULL,
        "person_name" character varying(150) NOT NULL,
        "kind" character varying(10) NOT NULL,
        "amount" numeric(16,2) NOT NULL,
        "note" character varying(500),
        "performed_by" character varying(80) NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "cancelled_at" TIMESTAMP WITH TIME ZONE,
        "cancelled_by" character varying(80),
        "cancel_reason" character varying(300),
        CONSTRAINT "PK_shop_debt_movements" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_shop_debt_movements_reference" UNIQUE ("reference"),
        CONSTRAINT "CHK_shop_debt_movements_kind" CHECK ("kind" IN ('borrow', 'repay')),
        CONSTRAINT "CHK_shop_debt_movements_amount" CHECK ("amount" > 0)
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_shop_debt_movements_person_created" ON "shop_debt_movements" (LOWER(TRIM("person_name")), "created_at" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "shop_debt_movements"`);
  }
}
