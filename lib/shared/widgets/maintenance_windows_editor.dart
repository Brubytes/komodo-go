import 'package:flutter/material.dart';
import 'package:komodo_go/core/theme/app_tokens.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/dialogs/confirm_destructive_dialog.dart';
import 'package:komodo_go/core/widgets/menus/komodo_select_menu_field.dart';
import 'package:komodo_go/core/widgets/sheets/editor_sheet_scaffold.dart';

/// Schedule types shared by every maintenance window model.
const List<String> maintenanceScheduleTypes = <String>[
  'Daily',
  'Weekly',
  'OneTime',
];

String maintenanceScheduleTypeLabel(String type) =>
    type == 'OneTime' ? 'One-time' : type;

/// Model-agnostic maintenance window used by [showMaintenanceWindowsEditor].
///
/// Servers and alerters map their own models to and from this draft.
@immutable
class MaintenanceWindowDraft {
  const MaintenanceWindowDraft({
    this.name = '',
    this.description = '',
    this.scheduleType = 'Daily',
    this.dayOfWeek = '',
    this.date = '',
    this.hour = 0,
    this.minute = 0,
    this.durationMinutes = 60,
    this.timezone = 'UTC',
    this.enabled = true,
  });

  final String name;
  final String description;

  /// One of [maintenanceScheduleTypes].
  final String scheduleType;
  final String dayOfWeek;
  final String date;
  final int hour;
  final int minute;
  final int durationMinutes;
  final String timezone;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is MaintenanceWindowDraft &&
      other.name == name &&
      other.description == description &&
      other.scheduleType == scheduleType &&
      other.dayOfWeek == dayOfWeek &&
      other.date == date &&
      other.hour == hour &&
      other.minute == minute &&
      other.durationMinutes == durationMinutes &&
      other.timezone == timezone &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
    name,
    description,
    scheduleType,
    dayOfWeek,
    date,
    hour,
    minute,
    durationMinutes,
    timezone,
    enabled,
  );
}

/// Opens the shared maintenance windows list editor.
///
/// [toDraft]/[fromDraft] map the caller's model to the neutral draft. Resolves
/// to the edited list, or null when dismissed.
Future<List<T>?> showMaintenanceWindowsEditor<T>(
  BuildContext context, {
  required List<T> initial,
  required MaintenanceWindowDraft Function(T) toDraft,
  required T Function(MaintenanceWindowDraft) fromDraft,
  String subtitle = 'Temporarily suppress alerts during scheduled maintenance.',
}) async {
  final result = await showEditorSheet<List<MaintenanceWindowDraft>>(
    context,
    (context) => MaintenanceWindowsListSheet(
      initial: initial.map(toDraft).toList(),
      subtitle: subtitle,
    ),
  );
  return result?.map(fromDraft).toList();
}

class MaintenanceWindowsListSheet extends StatefulWidget {
  const MaintenanceWindowsListSheet({
    required this.initial,
    required this.subtitle,
    super.key,
  });

  final List<MaintenanceWindowDraft> initial;
  final String subtitle;

  @override
  State<MaintenanceWindowsListSheet> createState() =>
      _MaintenanceWindowsListSheetState();
}

class _MaintenanceWindowsListSheetState
    extends State<MaintenanceWindowsListSheet> {
  late List<MaintenanceWindowDraft> _items;

  @override
  void initState() {
    super.initState();
    _items = List<MaintenanceWindowDraft>.from(widget.initial);
  }

  bool get _dirty {
    if (_items.length != widget.initial.length) return true;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i] != widget.initial[i]) return true;
    }
    return false;
  }

  Future<void> _add() async {
    final next = await MaintenanceWindowEditorSheet.show(context);
    if (!mounted) return;
    if (next != null) setState(() => _items = [..._items, next]);
  }

  Future<void> _edit(int index) async {
    final next = await MaintenanceWindowEditorSheet.show(
      context,
      initial: _items[index],
    );
    if (!mounted) return;
    if (next != null) setState(() => _items[index] = next);
  }

  Future<void> _remove(int index) async {
    final w = _items[index];
    final ok = await confirmDestructive(
      context,
      title: 'Remove maintenance window?',
      message: '"${w.name.isEmpty ? 'Maintenance' : w.name}" will be removed.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    setState(() => _items.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return EditorSheetScaffold(
      title: 'Maintenance windows',
      saveLabel: 'Done',
      dirty: _dirty,
      onSave: () => Navigator.of(context).pop(_items),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_items.isEmpty)
            Text(
              'No maintenance windows',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
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
                  '${maintenanceScheduleTypeLabel(w.scheduleType)} • '
                  '${w.timezone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(AppIcons.delete, color: scheme.error),
                  onPressed: () => _remove(index),
                ),
                onTap: () => _edit(index),
              ),
            ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _add,
              child: const Text('Add maintenance window'),
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceWindowEditorSheet extends StatefulWidget {
  const MaintenanceWindowEditorSheet({this.initial, super.key});

  final MaintenanceWindowDraft? initial;

  static Future<MaintenanceWindowDraft?> show(
    BuildContext context, {
    MaintenanceWindowDraft? initial,
  }) {
    return showEditorSheet<MaintenanceWindowDraft>(
      context,
      (context) => MaintenanceWindowEditorSheet(initial: initial),
    );
  }

  @override
  State<MaintenanceWindowEditorSheet> createState() =>
      _MaintenanceWindowEditorSheetState();
}

class _MaintenanceWindowEditorSheetState
    extends State<MaintenanceWindowEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _dayOfWeek;
  late final TextEditingController _date;
  late final TextEditingController _hour;
  late final TextEditingController _minute;
  late final TextEditingController _duration;
  late final TextEditingController _timezone;
  late String _scheduleType;
  late bool _enabled;
  var _nameTouched = false;

  MaintenanceWindowDraft get _initial =>
      widget.initial ?? const MaintenanceWindowDraft();

  @override
  void initState() {
    super.initState();
    final i = _initial;
    _name = TextEditingController(text: i.name);
    _description = TextEditingController(text: i.description);
    _dayOfWeek = TextEditingController(text: i.dayOfWeek);
    _date = TextEditingController(text: i.date);
    _hour = TextEditingController(text: i.hour.toString());
    _minute = TextEditingController(text: i.minute.toString());
    _duration = TextEditingController(text: i.durationMinutes.toString());
    _timezone = TextEditingController(text: i.timezone);
    _scheduleType = maintenanceScheduleTypes.contains(i.scheduleType)
        ? i.scheduleType
        : maintenanceScheduleTypes.first;
    _enabled = i.enabled;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _dayOfWeek,
      _date,
      _hour,
      _minute,
      _duration,
      _timezone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  MaintenanceWindowDraft _build() {
    final tz = _timezone.text.trim();
    return MaintenanceWindowDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      scheduleType: _scheduleType,
      dayOfWeek: _scheduleType == 'Weekly' ? _dayOfWeek.text.trim() : '',
      date: _scheduleType == 'OneTime' ? _date.text.trim() : '',
      hour: int.tryParse(_hour.text.trim()) ?? 0,
      minute: int.tryParse(_minute.text.trim()) ?? 0,
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 60,
      timezone: tz.isEmpty ? 'UTC' : tz,
      enabled: _enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    final nameEmpty = _name.text.trim().isEmpty;
    void changed() => setState(() {});

    return EditorSheetScaffold(
      title: isEditing ? 'Edit window' : 'Add window',
      dirty: _build() != _initial,
      canSave: !nameEmpty,
      onSave: () => Navigator.of(context).pop(_build()),
      child: Column(
        children: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _nameTouched = true),
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameTouched && nameEmpty ? 'Enter a name.' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _description,
            textInputAction: TextInputAction.next,
            onChanged: (_) => changed(),
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: AppSpacing.md),
          KomodoSelectMenuField<String>(
            key: ValueKey(_scheduleType),
            value: _scheduleType,
            items: [
              for (final t in maintenanceScheduleTypes)
                KomodoSelectMenuItem(
                  value: t,
                  label: maintenanceScheduleTypeLabel(t),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _scheduleType = v);
            },
            decoration: const InputDecoration(labelText: 'Schedule type'),
          ),
          if (_scheduleType == 'Weekly') ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _dayOfWeek,
              textInputAction: TextInputAction.next,
              onChanged: (_) => changed(),
              decoration: const InputDecoration(
                labelText: 'Day of week (e.g. Monday)',
              ),
            ),
          ],
          if (_scheduleType == 'OneTime') ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _date,
              textInputAction: TextInputAction.next,
              onChanged: (_) => changed(),
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hour,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => changed(),
                  decoration: const InputDecoration(labelText: 'Hour'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _minute,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => changed(),
                  decoration: const InputDecoration(labelText: 'Minute'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => changed(),
            decoration: const InputDecoration(labelText: 'Duration (minutes)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _timezone,
            textInputAction: TextInputAction.done,
            onChanged: (_) => changed(),
            decoration: const InputDecoration(labelText: 'Timezone'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
    );
  }
}
