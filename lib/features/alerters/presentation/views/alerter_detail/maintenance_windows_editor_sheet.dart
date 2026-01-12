import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';

class MaintenanceWindowsEditorSheet extends StatefulWidget {
  const MaintenanceWindowsEditorSheet({required this.initial, super.key});

  final List<AlerterMaintenanceWindow> initial;

  static Future<List<AlerterMaintenanceWindow>?> show(
    BuildContext context, {
    required List<AlerterMaintenanceWindow> initial,
  }) {
    return showModalBottomSheet<List<AlerterMaintenanceWindow>>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => MaintenanceWindowsEditorSheet(initial: initial),
    );
  }

  @override
  State<MaintenanceWindowsEditorSheet> createState() =>
      _MaintenanceWindowsEditorSheetState();
}

class _MaintenanceWindowsEditorSheetState
    extends State<MaintenanceWindowsEditorSheet> {
  late List<AlerterMaintenanceWindow> _items;

  @override
  void initState() {
    super.initState();
    _items = List<AlerterMaintenanceWindow>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Maintenance windows',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Gap(8),
          Text(
            'Temporarily suppress alerts during scheduled maintenance.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Gap(12),
          if (_items.isEmpty)
            Text(
              'No maintenance windows',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            for (final (index, w) in _items.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(w.name.isEmpty ? 'Maintenance' : w.name),
                subtitle: Text(
                  '${w.scheduleType} • ${w.timezone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(AppIcons.delete, color: scheme.error),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
                onTap: () => _editWindow(index),
              ),
            ],
          ],
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _addWindow,
              child: const Text('Add maintenance window'),
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_items),
              child: const Text('Done'),
            ),
          ),
          const Gap(12),
        ],
      ),
    );
  }

  Future<void> _addWindow() async {
    final next = await MaintenanceWindowEditorSheet.show(context);
    if (!mounted) return;
    if (next != null) setState(() => _items = [..._items, next]);
  }

  Future<void> _editWindow(int index) async {
    final current = _items[index];
    final next = await MaintenanceWindowEditorSheet.show(
      context,
      initial: current,
    );
    if (!mounted) return;
    if (next != null) setState(() => _items[index] = next);
  }
}

class MaintenanceWindowEditorSheet extends StatefulWidget {
  const MaintenanceWindowEditorSheet({this.initial, super.key});

  final AlerterMaintenanceWindow? initial;

  static Future<AlerterMaintenanceWindow?> show(
    BuildContext context, {
    AlerterMaintenanceWindow? initial,
  }) {
    return showModalBottomSheet<AlerterMaintenanceWindow>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => MaintenanceWindowEditorSheet(initial: initial),
    );
  }

  @override
  State<MaintenanceWindowEditorSheet> createState() =>
      _MaintenanceWindowEditorDialogState();
}

class _MaintenanceWindowEditorDialogState
    extends State<MaintenanceWindowEditorSheet> {
  static const List<String> _scheduleTypes = <String>[
    'Daily',
    'Weekly',
    'OneTime',
  ];

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String _scheduleType = _scheduleTypes.first;
  late final TextEditingController _dayOfWeekController;
  late final TextEditingController _dateController;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final TextEditingController _durationController;
  late final TextEditingController _timezoneController;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameController = TextEditingController(text: i?.name ?? '');
    _descriptionController = TextEditingController(text: i?.description ?? '');
    final st = i?.scheduleType.trim() ?? '';
    _scheduleType = _scheduleTypes.contains(st) ? st : _scheduleTypes.first;
    _dayOfWeekController = TextEditingController(text: i?.dayOfWeek ?? '');
    _dateController = TextEditingController(text: i?.date ?? '');
    _hourController = TextEditingController(text: (i?.hour ?? 0).toString());
    _minuteController = TextEditingController(
      text: (i?.minute ?? 0).toString(),
    );
    _durationController = TextEditingController(
      text: (i?.durationMinutes ?? 60).toString(),
    );
    _timezoneController = TextEditingController(text: i?.timezone ?? 'UTC');
    _enabled = i?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dayOfWeekController.dispose();
    _dateController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _durationController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, controller) => Stack(
        children: [
          ListView(
            controller: controller,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 96 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Edit maintenance window'
                          : 'Add maintenance window',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Gap(12),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const Gap(12),
              TextField(
                controller: _descriptionController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const Gap(12),
              KomodoSelectMenuField<String>(
                key: ValueKey(_scheduleType),
                value: _scheduleType,
                items: [
                  for (final t in _scheduleTypes)
                    KomodoSelectMenuItem(value: t, label: t),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _scheduleType = v);
                },
                decoration: const InputDecoration(labelText: 'Schedule type'),
              ),
              const Gap(12),
              if (_scheduleType == 'Weekly')
                TextField(
                  controller: _dayOfWeekController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Day of week (e.g. Mon)',
                  ),
                ),
              if (_scheduleType == 'OneTime') ...[
                const Gap(12),
                TextField(
                  controller: _dateController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                  ),
                ),
              ],
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hourController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Hour'),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: TextField(
                      controller: _minuteController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Minute'),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                ),
              ),
              const Gap(12),
              TextField(
                controller: _timezoneController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Timezone'),
              ),
              const Gap(8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) return;

                        Navigator.of(context).pop(
                          AlerterMaintenanceWindow(
                            name: name,
                            description: _descriptionController.text.trim(),
                            scheduleType: _scheduleType,
                            dayOfWeek: _scheduleType == 'Weekly'
                                ? _dayOfWeekController.text.trim()
                                : '',
                            date: _scheduleType == 'OneTime'
                                ? _dateController.text.trim()
                                : '',
                            hour:
                                int.tryParse(_hourController.text.trim()) ?? 0,
                            minute:
                                int.tryParse(_minuteController.text.trim()) ??
                                0,
                            durationMinutes:
                                int.tryParse(_durationController.text.trim()) ??
                                60,
                            timezone: _timezoneController.text.trim().isEmpty
                                ? 'UTC'
                                : _timezoneController.text.trim(),
                            enabled: _enabled,
                          ),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
