export var UserRole;
(function (UserRole) {
    UserRole["ADMIN"] = "admin";
    UserRole["EMPLOYEE"] = "employee";
})(UserRole || (UserRole = {}));
export var AppPermission;
(function (AppPermission) {
    AppPermission["VIEW_BALANCES"] = "view_balances";
    AppPermission["RECEIVE_COLLECTIONS"] = "receive_collections";
    AppPermission["MANAGE_ASSETS"] = "manage_assets";
    AppPermission["TOP_UP_ASSETS"] = "top_up_assets";
    AppPermission["INTERNAL_TRANSFER"] = "internal_transfer";
    AppPermission["DAILY_ROLLOVER"] = "daily_rollover";
    AppPermission["MANAGE_USERS"] = "manage_users";
    AppPermission["SELL_INVENTORY"] = "sell_inventory";
    AppPermission["MANAGE_INVENTORY"] = "manage_inventory";
    AppPermission["USE_MACHINES"] = "use_machines";
})(AppPermission || (AppPermission = {}));
export const ALL_PERMISSIONS = Object.values(AppPermission);
export const DEFAULT_EMPLOYEE_PERMISSIONS = [
    AppPermission.VIEW_BALANCES,
    AppPermission.RECEIVE_COLLECTIONS,
    AppPermission.SELL_INVENTORY,
    AppPermission.USE_MACHINES,
];
export const DEFAULT_USER_LIMITS = {
    maxReceiveAmount: null,
    maxTopUpAmount: null,
    maxSaleAmount: null,
    maxTransferAmount: null,
};
export var AccountType;
(function (AccountType) {
    AccountType["FAWRY"] = "fawry";
    AccountType["COMPANY"] = "company";
    AccountType["OPERATING"] = "operating";
})(AccountType || (AccountType = {}));
export var CollectionStatus;
(function (CollectionStatus) {
    CollectionStatus["PENDING"] = "pending";
    CollectionStatus["DONE"] = "done";
})(CollectionStatus || (CollectionStatus = {}));
export var ExecutionMode;
(function (ExecutionMode) {
    ExecutionMode["IMMEDIATE"] = "immediate";
    ExecutionMode["HOLD"] = "hold";
})(ExecutionMode || (ExecutionMode = {}));
export var LedgerCategory;
(function (LedgerCategory) {
    LedgerCategory["OPENING_BALANCE"] = "opening_balance";
    LedgerCategory["TOP_UP"] = "top_up";
    LedgerCategory["INTERNAL_TRANSFER"] = "internal_transfer";
    LedgerCategory["CASH_RECEIPT"] = "cash_receipt";
    LedgerCategory["COMPANY_EXECUTION"] = "company_execution";
    LedgerCategory["COMMISSION"] = "commission";
    LedgerCategory["MACHINE_USAGE"] = "machine_usage";
    LedgerCategory["DAILY_ROLLOVER"] = "daily_rollover";
    LedgerCategory["REVERSAL"] = "reversal";
})(LedgerCategory || (LedgerCategory = {}));
export var NotificationKind;
(function (NotificationKind) {
    NotificationKind["DEPOSIT"] = "deposit";
    NotificationKind["WITHDRAWAL"] = "withdrawal";
    NotificationKind["TRANSFER"] = "transfer";
    NotificationKind["INFO"] = "info";
})(NotificationKind || (NotificationKind = {}));
export var InventoryCategory;
(function (InventoryCategory) {
    InventoryCategory["MOBILE"] = "mobile";
    InventoryCategory["ACCESSORY"] = "accessory";
    InventoryCategory["CASE"] = "case";
    InventoryCategory["SCREEN"] = "screen";
    InventoryCategory["OTHER"] = "other";
})(InventoryCategory || (InventoryCategory = {}));
//# sourceMappingURL=enums.js.map