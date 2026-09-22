import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DataCard extends StatelessWidget {
  const DataCard({super.key, required this.columns, required this.rows});
  final List<String> columns;
  final List<List<Object>> rows;
  @override
  Widget build(BuildContext context) => Card(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4F7)),
          horizontalMargin: 24,
          columnSpacing: 42,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 66,
          columns: columns
              .map(
                (c) => DataColumn(
                  label: Text(
                    c,
                    style: const TextStyle(
                      color: HesbaColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
              .toList(),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: row
                      .map(
                        (cell) => DataCell(
                          cell is Widget
                              ? cell
                              : Text(
                                  '$cell',
                                  style: const TextStyle(
                                    color: HesbaColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}
