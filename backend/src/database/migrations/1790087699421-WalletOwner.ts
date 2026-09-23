import { MigrationInterface, QueryRunner } from 'typeorm';

export class WalletOwner1790087699421 implements MigrationInterface {
  name = 'WalletOwner1790087699421';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "wallets" ADD COLUMN IF NOT EXISTS "owner_name" varchar(120) NOT NULL DEFAULT ''`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "wallets" DROP COLUMN IF EXISTS "owner_name"`,
    );
  }
}
