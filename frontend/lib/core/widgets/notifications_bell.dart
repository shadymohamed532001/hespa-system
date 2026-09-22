import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../features/auth/session_controller.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../theme/app_theme.dart';
import '../utils/money_formatter.dart';

class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, required this.session});

  final SessionController session;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  Timer? _timer;
  int _unread = 0;
  List<dynamic> _items = [];
  bool _loadingList = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshCount(),
    );
  }

  @override
  void dispose() {
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
      if (mounted) setState(() => _unread = count);
      _overlay?.markNeedsBuild();
    } catch (_) {}
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
            backgroundColor: const Color(0xFFB42318),
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
            backgroundColor: const Color(0xFFB42318),
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
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: HesbaColors.border),
        ),
        child: InkWell(
          onTap: _togglePanel,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: HesbaColors.navy,
                  size: 22,
                ),
                if (_unread > 0)
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB42318),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _unread > 9 ? '9+' : '$_unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
    required this.onDismiss,
    required this.onMarkAll,
    required this.onOpen,
  });

  final LayerLink link;
  final bool loading;
  final List<dynamic> items;
  final int unread;
  final VoidCallback onDismiss;
  final VoidCallback onMarkAll;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
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
            color: Colors.white,
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
                        const Expanded(
                          child: Text(
                            'الإشعارات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: HesbaColors.ink,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          TextButton(
                            onPressed: onMarkAll,
                            child: const Text('تعيين الكل كمقروء'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE9EEF2)),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد إشعارات بعد',
                              style: TextStyle(color: HesbaColors.muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0xFFF0F3F5),
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index] as Map<String, dynamic>;
                              return _NotificationTile(
                                item: item,
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
  const _NotificationTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = '${item['kind']}';
    final unread = item['isRead'] != true;
    final amount = item['amount'];
    final createdAt = DateTime.tryParse('${item['createdAt']}')?.toLocal();

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? const Color(0xFFF3FAF8) : Colors.transparent,
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
                      color: HesbaColors.ink,
                      fontSize: 13,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['body']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HesbaColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (createdAt != null)
                        Text(
                          DateFormat('d MMM، h:mm a', 'ar').format(createdAt),
                          style: const TextStyle(
                            color: Color(0xFF8A9AA5),
                            fontSize: 11,
                          ),
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
    'withdrawal' => const Color(0xFFB42318),
    'transfer' => const Color(0xFF50657D),
    _ => HesbaColors.navy,
  };
}
