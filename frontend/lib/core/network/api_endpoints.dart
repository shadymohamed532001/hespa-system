abstract final class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String login = '/auth/login';
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

  static String notificationRead(String id) => '$notifications/$id/read';

  static String notificationsList({int? limit}) =>
      limit == null ? notifications : '$notifications?limit=$limit';

  // Wallets
  static const String wallets = '/wallets';

  static String walletTopUp(String id) => '$wallets/$id/top-up';

  // Machines
  static const String machines = '/machines';

  static String machineLoad(String id) => '$machines/$id/load';
  static String machineUse(String id) => '$machines/$id/use';
  static String machineStatus(String id) => '$machines/$id/status';

  // Collections
  static const String collections = '/collections';
  static const String receiveCollection = '$collections/receive';

  static String executeCollection(String id) => '$collections/$id/execute';

  // Treasury
  static const String treasury = '/treasury';
  static const String treasurySummary = '$treasury/summary';
  static const String treasuryTransfer = '$treasury/transfer';
  static const String treasuryRollover = '$treasury/rollover';

  // Ledger
  static const String ledger = '/ledger';

  static String ledgerList({int? limit}) =>
      limit == null ? ledger : '$ledger?limit=$limit';
}
