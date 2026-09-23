export enum UserRole {
  ADMIN = 'admin',
  EMPLOYEE = 'employee',
}

/** Fine-grained actions an employee account may be allowed to perform. */
export enum AppPermission {
  VIEW_BALANCES = 'view_balances',
  RECEIVE_COLLECTIONS = 'receive_collections',
  MANAGE_ASSETS = 'manage_assets',
  TOP_UP_ASSETS = 'top_up_assets',
  INTERNAL_TRANSFER = 'internal_transfer',
  DAILY_ROLLOVER = 'daily_rollover',
  MANAGE_USERS = 'manage_users',
  SELL_INVENTORY = 'sell_inventory',
  MANAGE_INVENTORY = 'manage_inventory',
  USE_MACHINES = 'use_machines',
  USE_WALLETS = 'use_wallets',
  REVERSE_OPERATIONS = 'reverse_operations',
  RECONCILE_BALANCES = 'reconcile_balances',
}

export const ALL_PERMISSIONS = Object.values(AppPermission);

export const DEFAULT_EMPLOYEE_PERMISSIONS: AppPermission[] = [
  AppPermission.VIEW_BALANCES,
  AppPermission.RECEIVE_COLLECTIONS,
  AppPermission.SELL_INVENTORY,
  AppPermission.USE_MACHINES,
  AppPermission.USE_WALLETS,
];

export type UserLimits = {
  /** Max amount for a single cash receive / collection execute. null = unlimited */
  maxReceiveAmount: number | null;
  /** Max amount for a single account/wallet top-up. null = unlimited */
  maxTopUpAmount: number | null;
  /** Max amount for a single inventory sale. null = unlimited */
  maxSaleAmount: number | null;
  /** Max amount for a single internal transfer. null = unlimited */
  maxTransferAmount: number | null;
};

export const DEFAULT_USER_LIMITS: UserLimits = {
  maxReceiveAmount: null,
  maxTopUpAmount: null,
  maxSaleAmount: null,
  maxTransferAmount: null,
};

export enum AccountType {
  FAWRY = 'fawry',
  COMPANY = 'company',
  OPERATING = 'operating',
}

export enum CollectionStatus {
  PENDING = 'pending',
  DONE = 'done',
  REVERSED = 'reversed',
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
  WALLET_USAGE = 'wallet_usage',
  DAILY_ROLLOVER = 'daily_rollover',
  REVERSAL = 'reversal',
  RECONCILIATION = 'reconciliation',
}

export enum InventoryMovementType {
  OPENING = 'opening',
  STOCK_IN = 'stock_in',
  SALE = 'sale',
  REVERSAL = 'reversal',
}

export enum NotificationKind {
  DEPOSIT = 'deposit',
  WITHDRAWAL = 'withdrawal',
  TRANSFER = 'transfer',
  INFO = 'info',
}

export enum InventoryCategory {
  MOBILE = 'mobile',
  ACCESSORY = 'accessory',
  CASE = 'case',
  SCREEN = 'screen',
  OTHER = 'other',
}
