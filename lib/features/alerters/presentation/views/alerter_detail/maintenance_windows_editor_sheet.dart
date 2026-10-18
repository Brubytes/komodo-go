import 'package:flutter/material.dart';
import 'package:komodo_go/features/alerters/data/models/alerter.dart';
import 'package:komodo_go/shared/widgets/maintenance_windows_editor.dart';

/// Alerter flavour of the shared maintenance windows editor.
abstract final class MaintenanceWindowsEditorSheet {
  static Future<List<AlerterMaintenanceWindow>?> show(
    BuildContext context, {
    required List<AlerterMaintenanceWindow> initial,
  }) {
    return showMaintenanceWindowsEditor<AlerterMaintenanceWindow>(
      context,
      initial: initial,
      toDraft: (w) => MaintenanceWindowDraft(
        name: w.name,
        description: w.description,
        scheduleType: maintenanceScheduleTypes.contains(w.scheduleType.trim())
            ? w.scheduleType.trim()
            : 'Daily',
        dayOfWeek: w.dayOfWeek,
        date: w.date,
        hour: w.hour,
        minute: w.minute,
        durationMinutes: w.durationMinutes,
        timezone: w.timezone.isEmpty ? 'UTC' : w.timezone,
        enabled: w.enabled,
      ),
      fromDraft: (d) => AlerterMaintenanceWindow(
        name: d.name,
        description: d.description,
        scheduleType: d.scheduleType,
        dayOfWeek: d.dayOfWeek,
        date: d.date,
        hour: d.hour,
        minute: d.minute,
        durationMinutes: d.durationMinutes,
        timezone: d.timezone,
        enabled: d.enabled,
      ),
    );
  }
}
