import { MigrationInterface, QueryRunner } from 'typeorm';

export class DevicePushTokens1790087699422 implements MigrationInterface {
  name = 'DevicePushTokens1790087699422';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "device_push_tokens" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "token" character varying(512) NOT NULL,
        "platform" character varying(40) NOT NULL DEFAULT 'unknown',
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_device_push_tokens" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_device_push_tokens_token" UNIQUE ("token")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_device_push_tokens_user_id" ON "device_push_tokens" ("user_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_device_push_tokens_user_id"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "device_push_tokens"`);
  }
}
