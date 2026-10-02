import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_advanced_menu.dart';
import 'package:komodo_go/features/actions/presentation/providers/actions_provider.dart';
import 'package:komodo_go/features/actions/presentation/views/action_detail_view.dart';
import 'package:komodo_go/features/procedures/presentation/providers/procedures_provider.dart';
import 'package:komodo_go/features/procedures/presentation/views/procedure_detail_view.dart';
import 'package:komodo_go/features/servers/presentation/providers/servers_provider.dart';
import 'package:komodo_go/features/servers/presentation/views/server_detail_view.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

class AdvancedActionDetailView extends ConsumerWidget {
  const AdvancedActionDetailView({
    required this.actionId,
    required this.actionName,
    super.key,
  });

  final String actionId;
  final String actionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(actionDetailProvider(actionId)).asData?.value;
    return ActionDetailView(
      actionId: actionId,
      actionName: actionName,
      appBarActions: [
        if (action != null)
          ResourceAdvancedMenuButton(
            metadata: ResourceMetadata(
              kind: ResourceKind.actions,
              id: action.id,
              name: action.name,
              description: action.description,
              template: action.template,
              tags: action.tags,
            ),
            onMutated: () {
              ref
                ..invalidate(actionsProvider)
                ..invalidate(actionDetailProvider(actionId));
            },
          ),
      ],
    );
  }
}

class AdvancedProcedureDetailView extends ConsumerWidget {
  const AdvancedProcedureDetailView({
    required this.procedureId,
    required this.procedureName,
    super.key,
  });

  final String procedureId;
  final String procedureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final procedure = ref
        .watch(procedureDetailProvider(procedureId))
        .asData
        ?.value;
    return ProcedureDetailView(
      procedureId: procedureId,
      procedureName: procedureName,
      appBarActions: [
        if (procedure != null)
          ResourceAdvancedMenuButton(
            metadata: ResourceMetadata(
              kind: ResourceKind.procedures,
              id: procedure.id,
              name: procedure.name,
              description: procedure.description,
              template: procedure.template,
              tags: procedure.tags,
            ),
            onMutated: () {
              ref
                ..invalidate(proceduresProvider)
                ..invalidate(procedureDetailProvider(procedureId));
            },
          ),
      ],
    );
  }
}

class AdvancedServerDetailView extends ConsumerWidget {
  const AdvancedServerDetailView({
    required this.serverId,
    required this.serverName,
    super.key,
  });

  final String serverId;
  final String serverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverDetailProvider(serverId)).asData?.value;
    return ServerDetailView(
      serverId: serverId,
      serverName: serverName,
      appBarActions: [
        if (server != null)
          ResourceAdvancedMenuButton(
            metadata: ResourceMetadata(
              kind: ResourceKind.servers,
              id: server.id,
              name: server.name,
              description: server.description ?? '',
              template: server.template,
              tags: server.tags,
            ),
            onMutated: () {
              ref
                ..invalidate(serversProvider)
                ..invalidate(serverDetailProvider(serverId));
            },
          ),
      ],
    );
  }
}
