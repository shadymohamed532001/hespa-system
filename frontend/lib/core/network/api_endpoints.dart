abstract final class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String login = '/auth/login';
  static const String recoverAdmin = '/auth/recover-admin';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  // Accounts
  static const String accounts = '/accounts';

  static String accountsList({bool includeInactive = false}) =>
      includeInactive ? '$accounts?includeInactive=true' : accounts;

  static String account(String id) => '$accounts/$id';
  static String accountTopUp(String id) => '${account(id)}/top-up';
  static String accountStatus(String id) => '${account(id)}/status';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '$notifications/unread-count';
  static const String notificationsReadAll = '$notifications/read-all';
  static const String notificationDeviceToken = '$notifications/device-token';
  static const String notificationDeviceTokenUnregister =
      '$notifications/device-token/unregister';

  static String notificationRead(String id) => '$notifications/$id/read';

  static String notificationsList({int? limit}) =>
      limit == null ? notifications : '$notifications?limit=$limit';

  // Wallets
  static const String wallets = '/wallets';

  static String walletsList({bool includeInactive = false}) =>
      includeInactive ? '$wallets?includeInactive=true' : wallets;

  static String wallet(String id) => '$wallets/$id';
  static String walletTopUp(String id) => '$wallets/$id/top-up';
  static String walletCustomerOperation(String id) =>
      '$wallets/$id/customer-operation';
  static String walletStatus(String id) => '$wallets/$id/status';

  // Machines
  static const String machines = '/machines';

  static String machinesList({bool includeInactive = false}) =>
      includeInactive ? '$machines?includeInactive=true' : machines;

  static String machine(String id) => '$machines/$id';
  static String machineLoad(String id) => '$machines/$id/load';
  static String machineUse(String id) => '$machines/$id/use';
  static String machineStatus(String id) => '$machines/$id/status';

  // Collections
  static const String collections = '/collections';
  static const String receiveCollection = '$collections/receive';

  static String executeCollection(String id) => '$collections/$id/execute';
  static String reverseCollection(String id) => '$collections/$id/reverse';

  // Treasury
  static const String treasury = '/treasury';
  static const String treasurySummary = '$treasury/summary';
  static const String treasuryTransfer = '$treasury/transfer';
  static const String treasuryRollover = '$treasury/rollover';
  static const String treasuryCloseDay = '$treasury/close-day';
  static const String treasuryReconcile = '$treasury/reconcile';
  static const String treasuryDailyCloses = '$treasury/daily-closes';

  // Ledger
  static const String ledger = '/ledger';

  static String ledgerList({int? limit}) =>
      limit == null ? ledger : '$ledger?limit=$limit';
  static String reverseLedgerEntry(String id) => '$ledger/$id/reverse';

  // Reports
  static const String reports = '/reports';

  static String reportsSummary({
    required DateTime from,
    required DateTime toExclusive,
    String entityType = 'all',
    String? entityId,
  }) {
    final query = <String, String>{
      'from': from.toUtc().toIso8601String(),
      'to': toExclusive.toUtc().toIso8601String(),
      'entityType': entityType,
    };
    if (entityId != null) query['entityId'] = entityId;
    return Uri(path: '$reports/summary', queryParameters: query).toString();
  }

  // Inventory (separate from cash treasury)
  static const String inventory = '/inventory';
  static const String inventoryProducts = '$inventory/products';
  static const String inventorySales = '$inventory/sales';
  static const String inventoryTreasurySummary = '$inventory/treasury/summary';
  static const String inventoryMovements = '$inventory/movements';

  static String inventoryStockIn(String id) =>
      '$inventoryProducts/$id/stock-in';
  static String inventorySell(String id) => '$inventoryProducts/$id/sell';
  static String reverseInventorySale(String id) =>
      '$inventorySales/$id/reverse';

  static String inventorySalesList({int? limit}) =>
      limit == null ? inventorySales : '$inventorySales?limit=$limit';

  // Users & permissions
  static const String users = '/users';
  static const String usersPermissionCatalog = '$users/permission-catalog';

  static String user(String id) => '$users/$id';
  static String userStatus(String id) => '${user(id)}/status';
}
