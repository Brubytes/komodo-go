import 'package:flutter/material.dart';
import 'package:komodo_go/features/servers/data/models/server.dart';
import 'package:komodo_go/shared/widgets/maintenance_windows_editor.dart';

/// Server flavour of the shared maintenance windows editor.
abstract final class ServerMaintenanceWindowsEditorSheet {
  static Future<List<MaintenanceWindow>?> show(
    BuildContext context, {
    required List<MaintenanceWindow> initial,
  }) {
    return showMaintenanceWindowsEditor<MaintenanceWindow>(
      context,
      initial: initial,
      subtitle: 'Schedule server maintenance to suppress alerts.',
      toDraft: (w) => MaintenanceWindowDraft(
        name: w.name,
        description: w.description,
        scheduleType: switch (w.scheduleType) {
          MaintenanceScheduleType.daily => 'Daily',
          MaintenanceScheduleType.weekly => 'Weekly',
          MaintenanceScheduleType.oneTime => 'OneTime',
        },
        dayOfWeek: w.dayOfWeek,
        date: w.date,
        hour: w.hour,
        minute: w.minute,
        durationMinutes: w.durationMinutes,
        timezone: w.timezone.isEmpty ? 'UTC' : w.timezone,
        enabled: w.enabled,
      ),
      fromDraft: (d) => MaintenanceWindow(
        name: d.name,
        description: d.description,
        scheduleType: switch (d.scheduleType) {
          'Weekly' => MaintenanceScheduleType.weekly,
          'OneTime' => MaintenanceScheduleType.oneTime,
          _ => MaintenanceScheduleType.daily,
        },
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
