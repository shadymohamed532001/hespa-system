import { MigrationInterface, QueryRunner } from 'typeorm';

const EMPLOYEE_DEFAULT_PERMISSIONS = JSON.stringify([
  'view_balances',
  'receive_collections',
  'sell_inventory',
  'manage_inventory',
  'use_machines',
  'use_wallets',
]);

export class EmployeeManageInventory1790087699423
  implements MigrationInterface
{
  name = 'EmployeeManageInventory1790087699423';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "permissions" SET DEFAULT '${EMPLOYEE_DEFAULT_PERMISSIONS}'::jsonb`,
    );

    // Grant manage_inventory to existing employees who do not already have it.
    await queryRunner.query(`
      UPDATE "users"
      SET "permissions" = "permissions" || '["manage_inventory"]'::jsonb
      WHERE "role" = 'employee'
        AND NOT ("permissions" @> '["manage_inventory"]'::jsonb)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      UPDATE "users"
      SET "permissions" = COALESCE(
        (
          SELECT jsonb_agg(value)
          FROM jsonb_array_elements("permissions") AS value
          WHERE value <> '"manage_inventory"'::jsonb
        ),
        '[]'::jsonb
      )
      WHERE "role" = 'employee'
        AND "permissions" @> '["manage_inventory"]'::jsonb
    `);

    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "permissions" SET DEFAULT '["view_balances","receive_collections","sell_inventory","use_machines","use_wallets"]'::jsonb`,
    );
  }
}
