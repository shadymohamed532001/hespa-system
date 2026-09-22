import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DataCard extends StatelessWidget {
  const DataCard({super.key, required this.columns, required this.rows});
  final List<String> columns;
  final List<List<Object>> rows;
  @override
  Widget build(BuildContext context) => Card(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF2F5F8)),
              headingRowHeight: 54,
              horizontalMargin: 20,
              columnSpacing: 36,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 62,
              columns: columns
                  .map(
                    (c) => DataColumn(
                      label: Text(
                        c,
                        style: const TextStyle(
                          color: Color(0xFF607480),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
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
      ),
    ),
  );
}
