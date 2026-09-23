export declare enum UserRole {
    ADMIN = "admin",
    EMPLOYEE = "employee"
}
export declare enum AppPermission {
    VIEW_BALANCES = "view_balances",
    RECEIVE_COLLECTIONS = "receive_collections",
    MANAGE_ASSETS = "manage_assets",
    TOP_UP_ASSETS = "top_up_assets",
    INTERNAL_TRANSFER = "internal_transfer",
    DAILY_ROLLOVER = "daily_rollover",
    MANAGE_USERS = "manage_users",
    SELL_INVENTORY = "sell_inventory",
    MANAGE_INVENTORY = "manage_inventory",
    USE_MACHINES = "use_machines",
    REVERSE_OPERATIONS = "reverse_operations",
    RECONCILE_BALANCES = "reconcile_balances"
}
export declare const ALL_PERMISSIONS: AppPermission[];
export declare const DEFAULT_EMPLOYEE_PERMISSIONS: AppPermission[];
export type UserLimits = {
    maxReceiveAmount: number | null;
    maxTopUpAmount: number | null;
    maxSaleAmount: number | null;
    maxTransferAmount: number | null;
};
export declare const DEFAULT_USER_LIMITS: UserLimits;
export declare enum AccountType {
    FAWRY = "fawry",
    COMPANY = "company",
    OPERATING = "operating"
}
export declare enum CollectionStatus {
    PENDING = "pending",
    DONE = "done",
    REVERSED = "reversed"
}
export declare enum ExecutionMode {
    IMMEDIATE = "immediate",
    HOLD = "hold"
}
export declare enum LedgerCategory {
    OPENING_BALANCE = "opening_balance",
    TOP_UP = "top_up",
    INTERNAL_TRANSFER = "internal_transfer",
    CASH_RECEIPT = "cash_receipt",
    COMPANY_EXECUTION = "company_execution",
    COMMISSION = "commission",
    MACHINE_USAGE = "machine_usage",
    DAILY_ROLLOVER = "daily_rollover",
    REVERSAL = "reversal",
    RECONCILIATION = "reconciliation"
}
export declare enum InventoryMovementType {
    OPENING = "opening",
    STOCK_IN = "stock_in",
    SALE = "sale",
    REVERSAL = "reversal"
}
export declare enum NotificationKind {
    DEPOSIT = "deposit",
    WITHDRAWAL = "withdrawal",
    TRANSFER = "transfer",
    INFO = "info"
}
export declare enum InventoryCategory {
    MOBILE = "mobile",
    ACCESSORY = "accessory",
    CASE = "case",
    SCREEN = "screen",
    OTHER = "other"
}
