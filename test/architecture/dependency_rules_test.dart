import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _featureImportPrefix = 'package:komodo_go/features/';

const _compositionAllowList = {
  'lib/core/router/app_router.dart',
  'lib/composition/resources/resource_catalog_provider.dart',
  'lib/composition/resources/resource_name_resolver_provider.dart',
  'lib/composition/resources/resource_tag_options_provider.dart',
  'lib/composition/resources/resource_advanced_menu.dart',
  'lib/composition/resources/advanced_resource_detail_views.dart',
  'lib/composition/resources/resource_creation_view.dart',
  'lib/composition/home/home_view.dart',
  'lib/composition/home/widgets/home_dashboard_tiles.dart',
  'lib/composition/resources/resources_view.dart',
  'lib/composition/stacks/stack_updates_provider.dart',
  'lib/composition/stacks/stack_updates_tab.dart',
  'lib/composition/alerters/alerter_detail_view.dart',
  'lib/composition/alerters/resource_targets_editor_sheet.dart',
  'lib/composition/builds/build_detail_view.dart',
  'lib/composition/builds/build_detail_sections.dart',
  'lib/composition/containers/containers_provider.dart',
  'lib/composition/containers/containers_view.dart',
  'lib/composition/deployments/deployment_detail_view.dart',
  'lib/composition/deployments/deployment_detail_sections.dart',
  'lib/composition/deployments/deployments_list_view.dart',
  'lib/composition/repos/repo_detail_view.dart',
  'lib/composition/repos/repo_detail_sections.dart',
  'lib/composition/settings/add_connection_sheet.dart',
  'lib/composition/settings/connections_view.dart',
  'lib/composition/settings/settings_view.dart',
  'lib/composition/settings/auto_update_review_view.dart',
  'lib/composition/stacks/stack_config_editor.dart',
  'lib/composition/stacks/stack_detail_view.dart',
  'lib/composition/stacks/stacks_list_view.dart',
  'lib/composition/syncs/sync_detail_view.dart',
  'lib/composition/syncs/sync_detail_sections.dart',
  'lib/composition/syncs/advanced_sync_section.dart',
  'lib/composition/servers/servers_list_view.dart',
};

void main() {
  test('feature dependencies only flow through composition roots', () {
    final violations = <String>[];
    final libDir = Directory('lib');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }

      final path = entity.path.replaceAll(r'\', '/');
      final importerFeature = _featureForPath(path);
      final isShared = path.startsWith('lib/shared/');
      final isCore = path.startsWith('lib/core/');
      final isComposition = path.startsWith('lib/composition/');
      final isAllowedComposition = _compositionAllowList.contains(path);

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final importedFeature = _importedFeature(lines[index]);
        if (importedFeature == null) continue;

        if (isShared) {
          violations.add('$path:${index + 1} shared imports $importedFeature');
          continue;
        }

        if (isCore && !isAllowedComposition) {
          violations.add('$path:${index + 1} core imports $importedFeature');
          continue;
        }

        if (importerFeature != null && importerFeature != importedFeature) {
          violations.add(
            '$path:${index + 1} $importerFeature imports $importedFeature',
          );
          continue;
        }

        if (isComposition && !isAllowedComposition) {
          violations.add(
            '$path:${index + 1} composition file missing allow-list entry',
          );
          continue;
        }

        if (importerFeature == null && !isCore && !isComposition) {
          violations.add(
            '$path:${index + 1} root/importer file imports $importedFeature',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

String? _featureForPath(String path) {
  final match = RegExp('^lib/features/([^/]+)/').firstMatch(path);
  return match?.group(1);
}

String? _importedFeature(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('import ')) return null;
  final markerIndex = trimmed.indexOf(_featureImportPrefix);
  if (markerIndex == -1) return null;
  final start = markerIndex + _featureImportPrefix.length;
  final slash = trimmed.indexOf('/', start);
  if (slash == -1) return null;
  return trimmed.substring(start, slash);
}
