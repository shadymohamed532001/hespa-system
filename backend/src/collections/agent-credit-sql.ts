/**
 * SQL condition that keeps an agent_credit_payments row only while its ledger
 * entry has not been cancelled. A payment's ledger entry is either the
 * treasury cash receipt (entity agent_credit / payment id) or, when the money
 * went to a wallet or QR profit account, a top-up linked through
 * metadata.agentCreditPaymentId.
 */
export function activeAgentPaymentSql(alias: string): string {
  return `NOT EXISTS (SELECT 1 FROM ledger_entries original JOIN ledger_entries cancelled ON cancelled.reverses_entry_id = original.id WHERE (original.entity_type = 'agent_credit' AND original.entity_id = ${alias}.id::text AND original.category = 'cash_receipt') OR original.metadata->>'agentCreditPaymentId' = ${alias}.id::text)`;
}
