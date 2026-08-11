import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/api_client.dart';
import 'package:komodo_go/core/api/komodo_api_capabilities.dart';
import 'package:komodo_go/features/notifications/data/models/update_detail.dart';
import 'package:komodo_go/features/notifications/data/repositories/notifications_repository.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';
import 'package:komodo_go/features/stacks/data/repositories/stack_repository.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';
import 'package:komodo_go/shared/resources/data/resource_management_repository.dart';
import 'package:komodo_go/shared/resources/models/resource_kind.dart';
import 'package:komodo_go/shared/resources/models/resource_metadata.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void registerAdvancedEditsContractTests() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
            'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group(
    'Advanced resource edits (real backend)',
    () {
      late StackRepository stacks;
      late TagRepository tags;
      late ResourceManagementRepository management;
      late NotificationsRepository notifications;

      setUp(() async {
        await resetBackendIfConfigured(requireConfig(config));
        final client = buildTestClient(requireConfig(config), RpcRecorder());
        stacks = StackRepository(client);
        tags = TagRepository(client);
        // ResourceTarget uses the same tagged Serde representation across API
        // generations. Force the newer capability set here so this live 2.2
        // contract catches accidental version-dependent target encoding.
        management = ResourceManagementRepository(
          KomodoApiClient(
            buildTestDio(requireConfig(config)),
            // Explicitly exercise the capability set that previously emitted the invalid target.
            // ignore: avoid_redundant_argument_values
            capabilities: KomodoApiCapabilities.v23AndNewer,
          ),
        );
        notifications = NotificationsRepository(client);
      });

      test('metadata, lifecycle, and update details round-trip', () async {
        KomodoStack? original;
        KomodoTag? createdTag;
        String? copiedId;
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        final copyName = 'advanced-copy-$suffix';
        final renamedName = 'advanced-renamed-$suffix';

        try {
          final listed = expectRight(await stacks.listStacks());
          expect(listed, isNotEmpty);
          final seed = expectRight(await stacks.getStack(listed.first.id));
          original = seed;

          final tag = expectRight(
            await tags.createTag(
              name: 'advanced-tag-$suffix',
              color: TagColor.blue,
            ),
          );
          createdTag = tag;

          final newDescription = 'Advanced edits contract $suffix';
          final newTemplate = !seed.template;
          final newTags = <String>{...seed.tags, tag.id}.toList()..sort();
          expectRight(
            await management.updateMetadata(
              metadata: _metadataFor(seed),
              draft: ResourceMetadataDraft(
                description: newDescription,
                template: newTemplate,
                tags: newTags,
              ),
            ),
          );

          final metadataUpdated = await _waitForStack(
            stacks,
            seed.id,
            (stack) =>
                stack.description == newDescription &&
                stack.template == newTemplate &&
                stack.tags.toSet().containsAll(newTags),
          );
          expect(metadataUpdated.tags.toSet(), newTags.toSet());

          expectRight(
            await management.copy(
              kind: ResourceKind.stacks,
              id: seed.id,
              name: copyName,
            ),
          );
          copiedId = await waitForListItemId(
            listItems: () async {
              final items = expectRight(await stacks.listStacks());
              return items.map((item) => item.toJson()).toList();
            },
            name: copyName,
          );
          expect(expectRight(await stacks.getStack(copiedId)).name, copyName);

          expectRight(
            await management.rename(
              kind: ResourceKind.stacks,
              id: copiedId,
              name: renamedName,
            ),
          );
          final renamedId = await waitForListItemId(
            listItems: () async {
              final items = expectRight(await stacks.listStacks());
              return items.map((item) => item.toJson()).toList();
            },
            name: renamedName,
          );
          expect(renamedId, copiedId);

          expectRight(
            await management.delete(
              kind: ResourceKind.stacks,
              id: copiedId,
            ),
          );
          await _waitUntilStackMissing(stacks, copiedId);
          copiedId = null;

          final update = await _waitForReadableUpdate(notifications);
          expect(update.id, isNotEmpty);
          expect(update.operation, isNotEmpty);
          expect(update.startTs, greaterThan(0));
          expect(update.version.label, matches(RegExp(r'^\d+\.\d+\.\d+$')));
        } finally {
          if (original != null) {
            await management.updateMetadata(
              metadata: _metadataFor(original),
              draft: ResourceMetadataDraft(
                description: original.description,
                template: original.template,
                tags: original.tags,
              ),
            );
          }
          if (copiedId != null) {
            await management.delete(kind: ResourceKind.stacks, id: copiedId);
          } else {
            final current = await stacks.listStacks();
            final items = current.fold(
              (_) => <StackListItem>[],
              (value) => value,
            );
            for (final item in items.where(
              (item) => item.name == copyName || item.name == renamedName,
            )) {
              await management.delete(
                kind: ResourceKind.stacks,
                id: item.id,
              );
            }
          }
          if (createdTag != null) {
            await tags.deleteTag(id: createdTag.id);
          }
        }
      });
    },
    skip:
        missingConfigReason ??
        config?.skipReason() ??
        config?.requireResetReason(),
  );
}

void main() => registerAdvancedEditsContractTests();

ResourceMetadata _metadataFor(KomodoStack stack) {
  return ResourceMetadata(
    kind: ResourceKind.stacks,
    id: stack.id,
    name: stack.name,
    description: stack.description,
    template: stack.template,
    tags: stack.tags,
  );
}

Future<KomodoStack> _waitForStack(
  StackRepository repository,
  String id,
  bool Function(KomodoStack stack) matches,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final result = await repository.getStack(id);
    final stack = result.fold((_) => null, (value) => value);
    if (stack != null && matches(stack)) return stack;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  fail('Stack $id did not reach the expected state.');
}

Future<void> _waitUntilStackMissing(
  StackRepository repository,
  String id,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final listed = expectRight(await repository.listStacks());
    if (listed.every((stack) => stack.id != id)) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  fail('Stack $id was still present after deletion.');
}

Future<UpdateDetail> _waitForReadableUpdate(
  NotificationsRepository repository,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    final page = expectRight(await repository.listUpdates(page: 0));
    for (final item in page.updates.where((item) => item.id.isNotEmpty)) {
      final detail = await repository.getUpdate(item.id);
      final readable = detail.fold((_) => null, (value) => value);
      if (readable != null) return readable;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  fail('No readable update was returned by ListUpdates/GetUpdate.');
}
