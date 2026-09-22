export enum UserRole {
  ADMIN = 'admin',
  EMPLOYEE = 'employee',
}

export enum AccountType {
  FAWRY = 'fawry',
  COMPANY = 'company',
  OPERATING = 'operating',
}

export enum CollectionStatus {
  PENDING = 'pending',
  DONE = 'done',
}

export enum ExecutionMode {
  IMMEDIATE = 'immediate',
  HOLD = 'hold',
}

export enum LedgerCategory {
  OPENING_BALANCE = 'opening_balance',
  TOP_UP = 'top_up',
  INTERNAL_TRANSFER = 'internal_transfer',
  CASH_RECEIPT = 'cash_receipt',
  COMPANY_EXECUTION = 'company_execution',
  COMMISSION = 'commission',
  MACHINE_USAGE = 'machine_usage',
  DAILY_ROLLOVER = 'daily_rollover',
  REVERSAL = 'reversal',
}

