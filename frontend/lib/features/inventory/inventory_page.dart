import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';

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
      actions: widget.session.can(AppPermissions.manageInventory)
          ? [
              OutlinedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(ar: 'إضافة صنف', en: 'Add item')),
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
                          note: tr(
                            ar: 'إجمالي القطع المتبقية',
                            en: 'Total remaining units',
                          ),
                        ),
                        MetricCard(
                          label: tr(ar: 'إجمالي المباع', en: 'Total sold'),
                          value: '${summary['soldUnits'] ?? 0}',
                          note: 'كل المبيعات المسجّلة',
                        ),
                        if (widget.session.isAdmin)
                          MetricCard(
                            label: tr(ar: 'مجمل الربح', en: 'Gross profit'),
                            value: money(summary['grossProfit']),
                            note: 'المبيعات غير المعكوسة بعد تكلفة الشراء',
                          ),
                        MetricCard(
                          label: 'مبيعات اليوم',
                          value: money(summary['todaySalesAmount']),
                          note:
                              '${summary['todaySalesCount'] ?? 0} عملية اليوم',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _ProductsCard(
                  products: products,
                  canManage: widget.session.can(AppPermissions.manageInventory),
                  canSell: widget.session.can(AppPermissions.sellInventory),
                  showProfits: widget.session.isAdmin,
                  onSell: _sellProduct,
                  onStockIn: widget.session.can(AppPermissions.manageInventory)
                      ? _stockIn
                      : null,
                ),
                const SizedBox(height: 20),
                _SalesCard(
                  sales: sales,
                  showProfits: widget.session.isAdmin,
                  canReverse: widget.session.can(
                    AppPermissions.reverseOperations,
                  ),
                  onReverse: _reverseSale,
                ),
              ],
            ),
    );
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final stock = TextEditingController(text: '0');
    final price = TextEditingController(text: '0');
    final cost = TextEditingController(text: '0');
    var category = 'accessory';
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: tr(ar: 'إضافة صنف للمخزن', en: 'Add item to inventory'),
          subtitle: 'موبايل، إكسسوار، جراب، شاشة أو غيرها.',
          actions: HesbaModalActions(
            primaryLabel: tr(ar: 'إضافة', en: 'Add'),
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: Column(
            children: [
              HesbaModalField(
                label: 'اسم الصنف *',
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(),
                ),
              ),
              SizedBox(height: 18),
              HesbaModalField(
                label: tr(ar: 'النوع *', en: 'Type *'),
                child: DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem(
                      value: 'mobile',
                      child: Text(tr(ar: 'موبايل', en: 'Mobile')),
                    ),
                    DropdownMenuItem(
                      value: 'accessory',
                      child: Text(tr(ar: 'إكسسوار', en: 'Accessory')),
                    ),
                    DropdownMenuItem(
                      value: 'case',
                      child: Text(tr(ar: 'جراب', en: 'Case')),
                    ),
                    DropdownMenuItem(
                      value: 'screen',
                      child: Text(tr(ar: 'شاشة', en: 'Screen')),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(tr(ar: 'أخرى', en: 'Other')),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => category = v!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'الكمية الافتتاحية *',
                child: TextField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'تكلفة الشراء للقطعة *',
                child: TextField(
                  controller: cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'سعر البيع الافتراضي *',
                child: TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ),
            ],
          ),
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
        'costPrice': num.tryParse(cost.text) ?? 0,
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
    final cost = TextEditingController(text: '${product['costPrice'] ?? 0}');
    final supplier = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 460,
      builder: (ctx) => HesbaModalCard(
        title: 'توريد مخزون — ${product['name']}',
        subtitle: tr(
          ar: 'أضف كمية جديدة إلى المخزن.',
          en: 'Add a new quantity to inventory.',
        ),
        actions: HesbaModalActions(
          primaryLabel: 'تأكيد التوريد',
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        child: Column(
          children: [
            HesbaModalField(
              label: 'الكمية المضافة *',
              child: TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'تكلفة شراء القطعة',
              child: TextField(
                controller: cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'المورد (اختياري)',
              child: TextField(
                controller: supplier,
                decoration: const InputDecoration(),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.post(
        ApiEndpoints.inventoryStockIn('${product['id']}'),
        {
          'quantity': int.tryParse(qty.text) ?? 0,
          if (num.tryParse(cost.text) != null) 'unitCost': num.parse(cost.text),
          if (supplier.text.trim().isNotEmpty) 'supplier': supplier.text.trim(),
        },
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
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => HesbaModalCard(
        title: 'بيع — ${product['name']}',
        subtitle: 'المتاح في المخزن: ${product['stockQty'] ?? 0}',
        actions: HesbaModalActions(
          primaryLabel: 'تأكيد البيع',
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        footer: const Text(
          'المبلغ يدخل خزنة المخزن فقط، ولا يُضاف لخزنة الكاش.',
          textAlign: TextAlign.center,
          style: HesbaText.caption,
        ),
        child: Column(
          children: [
            HesbaModalField(
              label: 'الكمية المباعة *',
              child: TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'سعر القطعة *',
              child: TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'ملاحظة (اختياري)',
              child: TextField(
                controller: note,
                decoration: const InputDecoration(),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final response = await widget.session.api
          .post(ApiEndpoints.inventorySell('${product['id']}'), {
            'quantity': int.tryParse(qty.text) ?? 0,
            'unitPrice': num.tryParse(price.text) ?? 0,
            if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
          });
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

  Future<void> _reverseSale(Map<String, dynamic> sale) async {
    final reason = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 480,
      builder: (ctx) => HesbaModalCard(
        title: 'عكس بيع — ${sale['productName']}',
        subtitle: 'سيعود المخزون ويُخصم المبلغ من خزنة المخزن.',
        actions: HesbaModalActions(
          primaryLabel: tr(ar: 'تأكيد العكس', en: 'Confirm reversal'),
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        child: HesbaModalField(
          label: tr(ar: 'سبب العكس *', en: 'Reversal reason *'),
          child: TextField(
            controller: reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    final value = reason.text.trim();
    if (ok != true || value.length < 3) return;
    try {
      await widget.session.api.post(
        ApiEndpoints.reverseInventorySale('${sale['id']}'),
        {'reason': value},
      );
      await load();
      if (mounted) showAppSnack(context, 'تم عكس البيع وإرجاع المخزون');
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
    required this.canManage,
    required this.canSell,
    required this.showProfits,
    required this.onSell,
    required this.onStockIn,
  });

  final List<dynamic> products;
  final bool canManage;
  final bool canSell;
  final bool showProfits;
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
          Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(ar: 'أصناف المخزن', en: 'Inventory items'),
                  style: HesbaText.sectionTitle,
                ),
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
                      columns: [
                        DataColumn(
                          label: Text(
                            tr(ar: 'الصنف', en: 'Item'),
                            style: HesbaText.tableHeader,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            tr(ar: 'النوع', en: 'Type'),
                            style: HesbaText.tableHeader,
                          ),
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
                        if (showProfits)
                          DataColumn(
                            label: Text(
                              'التكلفة',
                              style: HesbaText.tableHeader,
                            ),
                          ),
                        DataColumn(
                          label: Text(
                            'سعر البيع',
                            style: HesbaText.tableHeader,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            tr(ar: 'إجراء', en: 'Action'),
                            style: HesbaText.tableHeader,
                          ),
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
                              if (showProfits)
                                DataCell(
                                  Text(
                                    money(e['costPrice']),
                                    style: HesbaText.tableCell,
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
                                    if (canSell)
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
                                    if (canManage && onStockIn != null) ...[
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
  const _SalesCard({
    required this.sales,
    required this.showProfits,
    required this.canReverse,
    required this.onReverse,
  });

  final List<dynamic> sales;
  final bool showProfits;
  final bool canReverse;
  final Future<void> Function(Map<String, dynamic>) onReverse;

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
          Padding(
            padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(ar: 'آخر المبيعات', en: 'Latest sales'),
                  style: HesbaText.sectionTitle,
                ),
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
                      columns: [
                        DataColumn(
                          label: Text(
                            tr(ar: 'التاريخ والوقت', en: 'Date & time'),
                            style: HesbaText.tableHeader,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            tr(ar: 'الصنف', en: 'Item'),
                            style: HesbaText.tableHeader,
                          ),
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
                        if (showProfits)
                          DataColumn(
                            label: Text(
                              tr(ar: 'مجمل الربح', en: 'Gross profit'),
                              style: HesbaText.tableHeader,
                            ),
                          ),
                        DataColumn(
                          label: Text('بواسطة', style: HesbaText.tableHeader),
                        ),
                        DataColumn(
                          label: Text(
                            tr(ar: 'الحالة', en: 'Status'),
                            style: HesbaText.tableHeader,
                          ),
                        ),
                      ],
                      rows: [
                        for (final e in sales)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  formatDateTime(e['createdAt']),
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
                              if (showProfits)
                                DataCell(
                                  Text(
                                    money(e['grossProfit']),
                                    style: HesbaText.tableCell.copyWith(
                                      color: HesbaColors.teal,
                                    ),
                                  ),
                                ),
                              DataCell(
                                Text(
                                  '${e['performedBy']}',
                                  style: HesbaText.tableCell,
                                ),
                              ),
                              DataCell(
                                e['reversedAt'] != null
                                    ? Text(
                                        tr(ar: 'معكوسة', en: 'Reversed'),
                                        style: TextStyle(color: Colors.red),
                                      )
                                    : canReverse
                                    ? TextButton(
                                        onPressed: () => onReverse(
                                          e as Map<String, dynamic>,
                                        ),
                                        child: const Text('عكس البيع'),
                                      )
                                    : const Text('مكتملة'),
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

String _categoryLabel(String category) => switch (category) {
  'mobile' => tr(ar: 'موبايل', en: 'Mobile'),
  'accessory' => tr(ar: 'إكسسوار', en: 'Accessory'),
  'case' => tr(ar: 'جراب', en: 'Case'),
  'screen' => tr(ar: 'شاشة', en: 'Screen'),
  _ => tr(ar: 'أخرى', en: 'Other'),
};
