export type CreditDayMovement = {
  date: string;
  agentName: string;
  credit: number | string;
  paid: number | string;
  refunded?: number | string;
  movementsCount: number | string;
};

export function buildAgentCreditDays(movements: CreditDayMovement[]) {
  const balances = new Map<string, number>();
  const cents = (value: number | string) => Math.round(Number(value) * 100);
  const rows = [...movements]
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((row) => {
      const key = row.agentName.trim().toLowerCase();
      const opening = balances.get(key) ?? 0;
      const closing =
        opening +
        cents(row.credit) +
        cents(row.refunded ?? 0) -
        cents(row.paid);
      balances.set(key, closing);
      return {
        date: row.date,
        agentName: row.agentName,
        openingBalance: opening / 100,
        credit: Number(row.credit),
        paid: Number(row.paid),
        refunded: Number(row.refunded ?? 0),
        closingBalance: closing / 100,
        movementsCount: Number(row.movementsCount),
      };
    });
  return rows
    .map((row) => ({
      ...row,
      balance: (balances.get(row.agentName.trim().toLowerCase()) ?? 0) / 100,
    }))
    .reverse();
}

export type AgentHistoryKind = 'collection' | 'opening' | 'payment' | 'refund';

export type AgentHistoryMovement = {
  id: string;
  kind: AgentHistoryKind;
  date: string | Date;
  reference: string | null;
  description: string;
  /** Collections only: the operation amount and what the agent handed over. */
  operationAmount?: number | string | null;
  receivedAmount?: number | string | null;
  status?: string | null;
  /** Signed change to what the agent owes: + credit, - payment/deposit. */
  change: number | string;
};

/**
 * An agent's full statement: every movement oldest-first with the balance
 * after it (positive = the agent owes us, negative = we hold a deposit),
 * returned newest-first with totals.
 */
export function buildAgentHistory(movements: AgentHistoryMovement[]) {
  const cents = (value: number | string | null | undefined) =>
    Math.round(Number(value ?? 0) * 100);
  let balance = 0;
  let credit = 0;
  let paid = 0;
  let refunded = 0;
  const rows = [...movements]
    .sort(
      (a, b) =>
        new Date(a.date).getTime() - new Date(b.date).getTime() ||
        a.id.localeCompare(b.id),
    )
    .map((movement) => {
      const change = cents(movement.change);
      balance += change;
      if (movement.kind === 'refund') refunded += change;
      else if (change > 0) credit += change;
      else paid -= change;
      return {
        ...movement,
        date: new Date(movement.date).toISOString(),
        operationAmount:
          movement.operationAmount == null
            ? null
            : cents(movement.operationAmount) / 100,
        receivedAmount:
          movement.receivedAmount == null
            ? null
            : cents(movement.receivedAmount) / 100,
        change: change / 100,
        balanceAfter: balance / 100,
      };
    });
  return {
    balance: balance / 100,
    totals: {
      credit: credit / 100,
      paid: paid / 100,
      refunded: refunded / 100,
      collections: rows.filter((row) => row.kind === 'collection').length,
    },
    movements: rows.reverse(),
  };
}
