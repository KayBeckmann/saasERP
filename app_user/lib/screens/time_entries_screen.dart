import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';

const _weekdayLabels = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';

String _formatHours(double hours) =>
    hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString();

/// Stundenerfassung mit Wochenansicht: ein Eintrag je Tag und Position,
/// optional einem Auftrag zugeordnet, mit Tages- und Wochensumme.
class TimeEntriesScreen extends StatefulWidget {
  const TimeEntriesScreen({super.key});

  @override
  State<TimeEntriesScreen> createState() => _TimeEntriesScreenState();
}

class _TimeEntriesScreenState extends State<TimeEntriesScreen> {
  late DateTime _weekStart;
  late Future<({List<TimeEntry> entries, List<Order> orders})> _future;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _future = _load();
  }

  Future<({List<TimeEntry> entries, List<Order> orders})> _load() async {
    final auth = context.read<AuthController>();
    final entries = await auth.apiClient.listTimeEntries(
      token: auth.token!,
      from: _weekStart,
      to: _weekStart.add(const Duration(days: 6)),
    );
    final orders = await auth.apiClient.listOrders(auth.token!);
    return (entries: entries, orders: orders);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _future = _load();
    });
  }

  Future<void> _openEntryDialog({
    required DateTime date,
    required List<Order> orders,
    TimeEntry? entry,
  }) async {
    final result = await showDialog<_TimeEntryFormResult>(
      context: context,
      builder: (_) => _TimeEntryDialog(date: date, orders: orders, entry: entry),
    );
    if (result == null) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    if (entry == null) {
      await auth.apiClient.createTimeEntry(
        token: auth.token!,
        req: CreateTimeEntryRequest(
          orderId: result.orderId,
          workDate: date,
          hours: result.hours,
          description: result.description,
        ),
      );
    } else {
      await auth.apiClient.updateTimeEntry(
        token: auth.token!,
        id: entry.id,
        req: UpdateTimeEntryRequest(
          orderId: result.orderId,
          workDate: date,
          hours: result.hours,
          description: result.description,
        ),
      );
    }
    _reload();
  }

  Future<void> _delete(TimeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text('Eintrag mit ${_formatHours(entry.hours)} Std. wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteTimeEntry(token: auth.token!, id: entry.id);
    _reload();
  }

  String? _orderLabel(String? orderId, List<Order> orders) {
    if (orderId == null) return null;
    for (final order in orders) {
      if (order.id == orderId) return '${order.orderNumber} — ${order.title}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stundenerfassung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Vorherige Woche',
            onPressed: () => _changeWeek(-1),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Aktuelle Woche',
            onPressed: () => setState(() {
              _weekStart = _mondayOf(DateTime.now());
              _future = _load();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Nächste Woche',
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          final entriesByDay = <int, List<TimeEntry>>{};
          for (final entry in data.entries) {
            final offset = entry.workDate.difference(_weekStart).inDays;
            entriesByDay.putIfAbsent(offset, () => []).add(entry);
          }
          final weekTotal = data.entries.fold<double>(0, (sum, e) => sum + e.hours);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Woche ${_formatDate(_weekStart)} – ${_formatDate(weekEnd)} · '
                'Summe: ${_formatHours(weekTotal)} Std.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < 7; i++)
                _DayCard(
                  date: _weekStart.add(Duration(days: i)),
                  label: _weekdayLabels[i],
                  entries: entriesByDay[i] ?? [],
                  orderLabel: (orderId) => _orderLabel(orderId, data.orders),
                  onAdd: () => _openEntryDialog(date: _weekStart.add(Duration(days: i)), orders: data.orders),
                  onEdit: (entry) => _openEntryDialog(
                    date: _weekStart.add(Duration(days: i)),
                    orders: data.orders,
                    entry: entry,
                  ),
                  onDelete: _delete,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.label,
    required this.entries,
    required this.orderLabel,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime date;
  final String label;
  final List<TimeEntry> entries;
  final String? Function(String? orderId) orderLabel;
  final VoidCallback onAdd;
  final void Function(TimeEntry entry) onEdit;
  final void Function(TimeEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final dayTotal = entries.fold<double>(0, (sum, e) => sum + e.hours);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              title: Text('$label, ${_formatDate(date)}'),
              subtitle: dayTotal > 0 ? Text('${_formatHours(dayTotal)} Std.') : null,
              trailing: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Eintrag hinzufügen',
                onPressed: onAdd,
              ),
            ),
            for (final entry in entries)
              ListTile(
                dense: true,
                leading: const SizedBox(width: 24),
                title: Text(
                  [
                    '${_formatHours(entry.hours)} Std.',
                    ?orderLabel(entry.orderId),
                    if (entry.description != null && entry.description!.isNotEmpty) entry.description!,
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Bearbeiten',
                      onPressed: () => onEdit(entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Löschen',
                      onPressed: () => onDelete(entry),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeEntryFormResult {
  const _TimeEntryFormResult({this.orderId, required this.hours, this.description});

  final String? orderId;
  final double hours;
  final String? description;
}

class _TimeEntryDialog extends StatefulWidget {
  const _TimeEntryDialog({required this.date, required this.orders, this.entry});

  final DateTime date;
  final List<Order> orders;
  final TimeEntry? entry;

  @override
  State<_TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  late final TextEditingController _hoursController =
      TextEditingController(text: widget.entry != null ? _formatHours(widget.entry!.hours) : '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.entry?.description ?? '');
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _orderId = widget.entry?.orderId;
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Eintrag hinzufügen' : 'Eintrag bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_weekdayLabels[widget.date.weekday - 1]}, ${_formatDate(widget.date)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Stunden'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _orderId,
            decoration: const InputDecoration(labelText: 'Auftrag (optional)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Kein Auftrag')),
              for (final order in widget.orders)
                DropdownMenuItem<String?>(
                  value: order.id,
                  child: Text('${order.orderNumber} — ${order.title}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _orderId = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Beschreibung (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final hours = double.tryParse(_hoursController.text.replaceAll(',', '.'));
            if (hours == null || hours <= 0) return;
            Navigator.pop(
              context,
              _TimeEntryFormResult(
                orderId: _orderId,
                hours: hours,
                description: _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
