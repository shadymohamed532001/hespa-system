import { MigrationInterface, QueryRunner } from 'typeorm';

export class AgentCreditPayments1790087699431 implements MigrationInterface {
  name = 'AgentCreditPayments1790087699431';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "agent_credit_payments" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "reference" character varying(40) NOT NULL,
        "agent_name" character varying(150) NOT NULL,
        "amount" numeric(16,2) NOT NULL,
        "performed_by" character varying(80) NOT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_agent_credit_payments" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_agent_credit_payments_reference" UNIQUE ("reference")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_agent_credit_payments_agent_created" ON "agent_credit_payments" ("agent_name", "created_at" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "agent_credit_payments"`);
  }
}
