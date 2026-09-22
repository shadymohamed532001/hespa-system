export var UserRole;
(function (UserRole) {
    UserRole["ADMIN"] = "admin";
    UserRole["EMPLOYEE"] = "employee";
})(UserRole || (UserRole = {}));
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