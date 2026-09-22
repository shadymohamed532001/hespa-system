import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.session});

  final SessionController session;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  Map<String, dynamic> summary = {};
  List<dynamic> products = [];
  List<dynamic> sales = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final values = await Future.wait([
        widget.session.api.getMap(ApiEndpoints.inventoryTreasurySummary),
        widget.session.api.list(ApiEndpoints.inventoryProducts),
        widget.session.api.list(ApiEndpoints.inventorySalesList(limit: 30)),
      ]);
      summary = values[0] as Map<String, dynamic>;
      products = values[1] as List<dynamic>;
      sales = values[2] as List<dynamic>;
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'مخزن الموبايلات والإكسسوارات',
      subtitle:
          'متابعة المخزون والمبيعات — فلوس المخزن في خزنة منفصلة عن خزنة الكاش',
      actions: widget.session.isAdmin
          ? [
              OutlinedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة صنف'),
              ),
            ]
          : const [],
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              ),
            )
          : error != null
          ? ErrorBox(message: error!, retry: load)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _IsolationNotice(),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 4
                        : constraints.maxWidth >= 760
                        ? 2
                        : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: columns == 1 ? 2.6 : 1.85,
                      children: [
                        MetricCard(
                          label: 'خزنة المخزن',
                          value: money(summary['balance']),
                          note: 'منفصلة عن خزنة الكاش',
                          accent: true,
                        ),
                        MetricCard(
                          label: 'بالمخزن الآن',
                          value: '${summary['stockUnits'] ?? 0}',
                          note: 'إجمالي القطع المتبقية',
                        ),
                        MetricCard(
                          label: 'إجمالي المباع',
                          value: '${summary['soldUnits'] ?? 0}',
                          note: 'كل المبيعات المسجّلة',
                        ),
                        MetricCard(
                          label: 'مبيعات اليوم',
                          value: money(summary['todaySalesAmount']),
                          note: '${summary['todaySalesCount'] ?? 0} عملية اليوم',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _ProductsCard(
                  products: products,
                  isAdmin: widget.session.isAdmin,
                  onSell: _sellProduct,
                  onStockIn: widget.session.isAdmin ? _stockIn : null,
                ),
                const SizedBox(height: 20),
                _SalesCard(sales: sales),
              ],
            ),
    );
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final stock = TextEditingController(text: '0');
    final price = TextEditingController(text: '0');
    var category = 'accessory';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('إضافة صنف للمخزن'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الصنف'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(value: 'mobile', child: Text('موبايل')),
                    DropdownMenuItem(
                      value: 'accessory',
                      child: Text('إكسسوار'),
                    ),
                    DropdownMenuItem(value: 'case', child: Text('جراب')),
                    DropdownMenuItem(value: 'screen', child: Text('شاشة')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setLocal(() => category = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية الافتتاحية',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'سعر البيع الافتراضي',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.post(ApiEndpoints.inventoryProducts, {
        'name': name.text.trim(),
        'category': category,
        'openingStock': int.tryParse(stock.text) ?? 0,
        'defaultPrice': num.tryParse(price.text) ?? 0,
      });
      await load();
      if (mounted) showAppSnack(context, 'تمت إضافة الصنف');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }

  Future<void> _stockIn(Map<String, dynamic> product) async {
    final qty = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('توريد مخزون — ${product['name']}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الكمية المضافة'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التوريد'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.post(
        ApiEndpoints.inventoryStockIn('${product['id']}'),
        {'quantity': int.tryParse(qty.text) ?? 0},
      );
      await load();
      if (mounted) showAppSnack(context, 'تم توريد الكمية للمخزن');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }

  Future<void> _sellProduct(Map<String, dynamic> product) async {
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(
      text: '${product['defaultPrice'] ?? 0}',
    );
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('بيع — ${product['name']}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المتاح في المخزن: ${product['stockQty'] ?? 0}',
                style: HesbaText.bodyMuted,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية المباعة'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'سعر القطعة'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'المبلغ يدخل خزنة المخزن فقط، ولا يُضاف لخزنة الكاش.',
                style: HesbaText.caption,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد البيع'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final response = await widget.session.api.post(
        ApiEndpoints.inventorySell('${product['id']}'),
        {
          'quantity': int.tryParse(qty.text) ?? 0,
          'unitPrice': num.tryParse(price.text) ?? 0,
          if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
        },
      );
      await load();
      if (!mounted) return;
      final message = response is Map && response['message'] != null
          ? '${response['message']}'
          : 'تم تسجيل البيع';
      showAppSnack(context, message);
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

class _IsolationNotice extends StatelessWidget {
  const _IsolationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F7),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text.rich(
        TextSpan(
          style: HesbaText.callout,
          children: const [
            TextSpan(
              text: 'خزنة منفصلة: ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text:
                  'إيرادات بيع الموبايلات والإكسسوارات تُحفظ في خزنة المخزن فقط، ولا تُخلط مع خزنة الكاش المركزية.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({
    required this.products,
    required this.isAdmin,
    required this.onSell,
    required this.onStockIn,
  });

  final List<dynamic> products;
  final bool isAdmin;
  final Future<void> Function(Map<String, dynamic>) onSell;
  final Future<void> Function(Map<String, dynamic>)? onStockIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أصناف المخزن', style: HesbaText.sectionTitle),
                SizedBox(height: 4),
                Text(
                  'بالمخزن · المباع · المتبقي · وسعر البيع',
                  style: HesbaText.panelSub,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9EEF2)),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Text(
                'لا توجد أصناف بعد',
                textAlign: TextAlign.center,
                style: HesbaText.bodyMuted,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF2F5F8),
                      ),
                      headingRowHeight: 52,
                      horizontalMargin: 18,
                      columnSpacing: 24,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 64,
                      columns: const [
                        DataColumn(
                          label: Text('الصنف', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('النوع', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('بالمخزن', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('مباع', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('متبقي', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text(
                            'سعر البيع',
                            style: HesbaText.tableHeader,
                          ),
                        ),
                        DataColumn(
                          label: Text('إجراء', style: HesbaText.tableHeader),
                        ),
                      ],
                      rows: [
                        for (final e in products)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '${e['name']}',
                                  style: HesbaText.tableEmphasis,
                                ),
                              ),
                              DataCell(
                                Text(
                                  _categoryLabel('${e['category']}'),
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e['stockQty']}',
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e['soldQty']}',
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e['remainingQty'] ?? e['stockQty']}',
                                  style: HesbaText.tableEmphasis.copyWith(
                                    color: HesbaColors.tealDark,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  money(e['defaultPrice']),
                                  style: HesbaText.tableCell.copyWith(
                                    color: HesbaColors.teal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FilledButton(
                                      onPressed:
                                          (e['stockQty'] as num? ?? 0) > 0
                                          ? () => onSell(
                                              e as Map<String, dynamic>,
                                            )
                                          : null,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: const Text('بيع'),
                                    ),
                                    if (onStockIn != null) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () => onStockIn!(
                                          e as Map<String, dynamic>,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text('توريد'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.sales});

  final List<dynamic> sales;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('آخر المبيعات', style: HesbaText.sectionTitle),
                SizedBox(height: 4),
                Text(
                  'الكمية والسعر والمبلغ الداخل لخزنة المخزن',
                  style: HesbaText.panelSub,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9EEF2)),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Text(
                'لا توجد مبيعات بعد',
                textAlign: TextAlign.center,
                style: HesbaText.bodyMuted,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF2F5F8),
                      ),
                      headingRowHeight: 52,
                      horizontalMargin: 18,
                      columnSpacing: 24,
                      dataRowMinHeight: 54,
                      dataRowMaxHeight: 58,
                      columns: const [
                        DataColumn(
                          label: Text('الوقت', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('الصنف', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('الكمية', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text(
                            'سعر القطعة',
                            style: HesbaText.tableHeader,
                          ),
                        ),
                        DataColumn(
                          label: Text('الإجمالي', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text('بواسطة', style: HesbaText.tableHeader),
                        ),
                      ],
                      rows: [
                        for (final e in sales)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  _formatTime(e['createdAt']),
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e['productName']}',
                                  style: HesbaText.tableEmphasis,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e['quantity']}',
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                Text(
                                  money(e['unitPrice']),
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                Text(
                                  money(e['totalAmount']),
                                  style: HesbaText.tableEmphasis.copyWith(
                                    color: HesbaColors.tealDark,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e['performedBy']}',
                                  style: HesbaText.tableCell,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static String _formatTime(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '—';
    return DateFormat('dd/MM  HH:mm').format(parsed);
  }
}

String _categoryLabel(String category) => switch (category) {
  'mobile' => 'موبايل',
  'accessory' => 'إكسسوار',
  'case' => 'جراب',
  'screen' => 'شاشة',
  _ => 'أخرى',
};
