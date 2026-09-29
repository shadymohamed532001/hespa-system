import { MigrationInterface, QueryRunner } from 'typeorm';

export class AgentCredit1790087699430 implements MigrationInterface {
  name = 'AgentCredit1790087699430';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "collections" ADD COLUMN IF NOT EXISTS "agent_credit_change" numeric(16,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_collections_agent_credit" ON "collections" ("agent_name") WHERE "agent_credit_change" <> 0`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_collections_agent_credit"`,
    );
    await queryRunner.query(
      `ALTER TABLE "collections" DROP COLUMN IF EXISTS "agent_credit_change"`,
    );
  }
}
