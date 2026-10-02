import { MigrationInterface, QueryRunner } from 'typeorm';

export class ProfitDepositToBalance1790087699436 implements MigrationInterface {
  name = 'ProfitDepositToBalance1790087699436';

  async up(queryRunner: QueryRunner): Promise<void> {
    // Run transactionally and prevent a concurrent top-up/reversal during conversion.
    await queryRunner.query(
      `LOCK TABLE financial_accounts, ledger_entries IN SHARE ROW EXCLUSIVE MODE`,
    );
    await queryRunner.query(`
      CREATE TEMP TABLE profit_deposits_to_credit ON COMMIT DROP AS
      SELECT c.id, c.entity_id, c.amount, s.id AS source_id
      FROM ledger_entries c
      JOIN financial_accounts a ON a.id::text = c.entity_id AND a.type = 'profit'
      JOIN ledger_entries s ON s.id::text = c.metadata->>'profitSourceEntryId'
        AND s.category = 'top_up' AND s.entity_id = c.entity_id
      WHERE c.category = 'commission' AND c.entity_type = 'account'
        AND c.metadata->>'profitCommissionKind' = 'deposit'
        AND c.amount > 0
        AND COALESCE(c.metadata->>'profitDepositCreditedToBalance', 'false') <> 'true'
        AND NOT EXISTS (
          SELECT 1 FROM ledger_entries r WHERE r.reverses_entry_id IN (c.id, s.id)
        )
    `);
    await queryRunner.query(`
      UPDATE financial_accounts a
      SET balance = a.balance + totals.amount,
          commission_balance = a.commission_balance - totals.amount,
          updated_at = NOW()
      FROM (SELECT entity_id, SUM(amount) amount FROM profit_deposits_to_credit GROUP BY entity_id) totals
      WHERE a.id::text = totals.entity_id
    `);
    await queryRunner.query(`
      UPDATE ledger_entries c
      SET metadata = COALESCE(c.metadata, '{}'::jsonb) ||
        '{"profitDepositCreditedToBalance":true,"profitDepositBalanceMigration":"1790087699436"}'::jsonb
      FROM profit_deposits_to_credit d WHERE c.id = d.id
    `);
    await queryRunner.query(`
      UPDATE ledger_entries s
      SET metadata = COALESCE(s.metadata, '{}'::jsonb) || jsonb_build_object(
        'profitDepositCreditedToBalance', true, 'profitDepositCommission', d.amount)
      FROM profit_deposits_to_credit d WHERE s.id = d.source_id
    `);
  }

  async down(): Promise<void> {
    throw new Error(
      'Deposit bonuses may already have been spent; use a reviewed balance reconciliation to undo this migration.',
    );
  }
}
