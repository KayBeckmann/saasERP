import 'package:flutter/material.dart';

/// Spaltendefinition für [AppDataTable]. [flex] steuert die relative
/// Breite, [numeric] richtet Header und Zellen rechts aus.
class AppDataColumn {
  const AppDataColumn(this.label, {this.numeric = false, this.flex = 1});

  final String label;
  final bool numeric;
  final int flex;
}

/// Eine Zeile in [AppDataTable]. [cells] muss dieselbe Länge wie die
/// Spaltenliste haben. [onTap] macht die Zeile klickbar (z. B. zum
/// Öffnen eines Editors), [trailing] zeigt zusätzliche Aktionen rechts
/// außerhalb der Spalten (z. B. Löschen-Button).
class AppDataRow {
  const AppDataRow({required this.cells, this.onTap, this.trailing});

  final List<Widget> cells;
  final VoidCallback? onTap;
  final Widget? trailing;
}

/// Datentabelle gemäß `mockup/craft_trade_erp_system/DESIGN.md`:
/// Sticky-Header in label-lg auf hellgrauem Grund, zebra-gestreifte
/// Zeilen (`#F8FAFB`), tabellarisch ausgerichtete Zahlenspalten.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyLabel = 'Keine Einträge.',
    this.trailingWidth = 48,
  });

  static const _zebraColor = Color(0xFFF8FAFB);
  static const _headerColor = Color(0xFFF1F3F5);

  final List<AppDataColumn> columns;
  final List<AppDataRow> rows;
  final String emptyLabel;
  final double trailingWidth;

  bool get _hasTrailing => rows.any((row) => row.trailing != null);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return Column(
      children: [
        _buildRow(
          context,
          cells: [
            for (final column in columns)
              Text(
                column.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: column.numeric ? TextAlign.right : TextAlign.left,
              ),
          ],
          flexes: columns.map((c) => c.flex).toList(),
          color: _headerColor,
          trailing: _hasTrailing ? const SizedBox.shrink() : null,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final body = _buildRow(
                context,
                cells: row.cells,
                flexes: columns.map((c) => c.flex).toList(),
                color: index.isOdd ? _zebraColor : Colors.transparent,
                trailing: row.trailing,
                numericFlags: columns.map((c) => c.numeric).toList(),
              );
              if (row.onTap == null) return body;
              return InkWell(onTap: row.onTap, child: body);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required List<Widget> cells,
    required List<int> flexes,
    required Color color,
    Widget? trailing,
    List<bool>? numericFlags,
  }) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i < flexes.length ? flexes[i] : 1,
              child: Align(
                alignment: (numericFlags != null && i < numericFlags.length && numericFlags[i])
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: cells[i],
              ),
            ),
          if (trailing != null) SizedBox(width: trailingWidth, child: trailing),
        ],
      ),
    );
  }
}
