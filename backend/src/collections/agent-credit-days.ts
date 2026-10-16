export type CreditDayMovement = {
  date: string;
  agentName: string;
  credit: number | string;
  paid: number | string;
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
      const closing = opening + cents(row.credit) - cents(row.paid);
      balances.set(key, closing);
      return {
        date: row.date,
        agentName: row.agentName,
        openingBalance: opening / 100,
        credit: Number(row.credit),
        paid: Number(row.paid),
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
