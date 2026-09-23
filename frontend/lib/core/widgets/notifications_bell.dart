import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../features/auth/session_controller.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../notifications/push_notifications_service.dart';
import '../settings/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/money_formatter.dart';
import 'header_icon_button.dart';
import '../settings/tr.dart';

class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, required this.session, this.strings});

  final SessionController session;
  final AppStrings? strings;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  Timer? _timer;
  int _unread = 0;
  int? _lastSeenUnread;
  final Set<String> _announcedIds = {};
  List<dynamic> _items = [];
  bool _loadingList = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  AppStrings get _t =>
      widget.strings ?? AppStrings.of(Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _refreshCount();
    // Faster poll so actions show a badge/local banner without waiting on FCM.
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshCount(),
    );
    PushNotificationsService.instance.onMessage = (_) {
      _refreshCount();
    };
  }

  @override
  void dispose() {
    if (PushNotificationsService.instance.onMessage != null) {
      PushNotificationsService.instance.onMessage = null;
    }
    _timer?.cancel();
    _closeOverlay();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    try {
      final data = await widget.session.api.getMap(
        ApiEndpoints.notificationsUnreadCount,
      );
      final count = int.tryParse('${data['count']}') ?? 0;
      final previous = _lastSeenUnread;
      if (mounted) setState(() => _unread = count);
      _overlay?.markNeedsBuild();

      // First baseline: don't spam local alerts for old unread items.
      if (previous == null) {
        _lastSeenUnread = count;
        return;
      }
      if (count > previous) {
        await _announceNewNotifications(count - previous);
      }
      _lastSeenUnread = count;
    } catch (_) {}
  }

  /// When FCM/APNs is down, still surface a macOS banner from the API feed.
  Future<void> _announceNewNotifications(int expectedNew) async {
    try {
      final list = await widget.session.api.list(
        ApiEndpoints.notificationsList(limit: 10),
      );
      final fresh = list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['isRead'] != true)
          .where((item) {
            final id = '${item['id']}';
            if (_announcedIds.contains(id)) return false;
            _announcedIds.add(id);
            return true;
          })
          .take(expectedNew.clamp(1, 3))
          .toList();

      for (final item in fresh) {
        await PushNotificationsService.instance.showLocal(
          title: '${item['title'] ?? tr(ar: 'حسبة', en: 'Hesba')}',
          body: '${item['body'] ?? ''}',
          payload: '${item['id']}',
        );
      }
    } catch (error) {
      debugPrint('Local notification announce failed: $error');
    }
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      _items = await widget.session.api.list(
        ApiEndpoints.notificationsList(limit: 30),
      );
      final unread = _items.where((item) => item['isRead'] != true).length;
      if (mounted) setState(() => _unread = unread);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(exception)),
            backgroundColor: HesbaColors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _loadingList = false);
    _overlay?.markNeedsBuild();
  }

  void _togglePanel() {
    if (_overlay != null) {
      _closeOverlay();
      return;
    }
    setState(() => _loadingList = true);
    _loadList();
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(
      builder: (context) => _NotificationsOverlay(
        link: _layerLink,
        loading: _loadingList,
        items: _items,
        unread: _unread,
        strings: _t,
        onDismiss: _closeOverlay,
        onMarkAll: _markAllRead,
        onOpen: _markOneRead,
      ),
    );
    overlay.insert(_overlay!);
  }

  void _closeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _markAllRead() async {
    try {
      await widget.session.api.post(ApiEndpoints.notificationsReadAll);
      await _loadList();
      await _refreshCount();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(exception)),
            backgroundColor: HesbaColors.red,
          ),
        );
      }
    }
  }

  Future<void> _markOneRead(String id) async {
    try {
      await widget.session.api.patch(ApiEndpoints.notificationRead(id), {});
      await _loadList();
      await _refreshCount();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HeaderIconButton(
            tooltip: _t.notificationsTooltip,
            onPressed: _togglePanel,
            icon: Icons.notifications_none_rounded,
          ),
          if (_unread > 0)
            Positioned.directional(
              textDirection: Directionality.of(context),
              top: 6,
              start: 6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: HesbaColors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  _unread > 9 ? '9+' : '$_unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationsOverlay extends StatelessWidget {
  const _NotificationsOverlay({
    required this.link,
    required this.loading,
    required this.items,
    required this.unread,
    required this.strings,
    required this.onDismiss,
    required this.onMarkAll,
    required this.onOpen,
  });

  final LayerLink link;
  final bool loading;
  final List<dynamic> items;
  final int unread;
  final AppStrings strings;
  final VoidCallback onDismiss;
  final VoidCallback onMarkAll;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF152833) : Colors.white;
    final ink = isDark ? const Color(0xFFE6EEF2) : HesbaColors.ink;
    final muted = isDark ? const Color(0xFF9AADB8) : HesbaColors.muted;
    final divider = isDark ? const Color(0xFF2A4050) : const Color(0xFFE9EEF2);
    final locale = Localizations.localeOf(context).languageCode;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Color(0x33000000)),
          ),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: Material(
            elevation: 10,
            color: surface,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 380,
              height: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.notificationsTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: ink,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          TextButton(
                            onPressed: onMarkAll,
                            child: Text(strings.markAllRead),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: divider),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                        ? Center(
                            child: Text(
                              strings.noNotifications,
                              style: TextStyle(color: muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: divider),
                            itemBuilder: (context, index) {
                              final item = items[index] as Map<String, dynamic>;
                              return _NotificationTile(
                                item: item,
                                locale: locale,
                                onTap: () {
                                  final id = '${item['id']}';
                                  if (item['isRead'] != true) onOpen(id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.locale,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final kind = '${item['kind']}';
    final unread = item['isRead'] != true;
    final amount = item['amount'];
    final createdAt = DateTime.tryParse('${item['createdAt']}')?.toLocal();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFE6EEF2) : HesbaColors.ink;
    final muted = isDark ? const Color(0xFF9AADB8) : HesbaColors.muted;
    final unreadBg = isDark ? const Color(0xFF1A3540) : const Color(0xFFF3FAF8);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? unreadBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kindColor(kind).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_kindIcon(kind), color: _kindColor(kind), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['title']}',
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['body']}',
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 12, height: 1.45),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (amount != null) ...[
                        Text(
                          money(amount),
                          style: TextStyle(
                            color: _kindColor(kind),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (createdAt != null)
                        Text(
                          DateFormat('d MMM, h:mm a', locale).format(createdAt),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: HesbaColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _kindIcon(String kind) => switch (kind) {
    'deposit' => Icons.south_west_rounded,
    'withdrawal' => Icons.north_east_rounded,
    'transfer' => Icons.swap_horiz_rounded,
    _ => Icons.info_outline_rounded,
  };

  static Color _kindColor(String kind) => switch (kind) {
    'deposit' => HesbaColors.teal,
    'withdrawal' => HesbaColors.red,
    'transfer' => const Color(0xFF50657D),
    _ => HesbaColors.navy,
  };
}
