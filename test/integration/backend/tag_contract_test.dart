import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/data/repositories/tag_repository.dart';

import '../../support/backend_test_config.dart';
import '../../support/backend_test_helpers.dart';

void main() {
  final config = BackendTestConfig.fromEnvironment();
  final missingConfigReason = config == null
      ? 'Set KOMODO_TEST_BASE_URL, KOMODO_TEST_API_KEY, and '
          'KOMODO_TEST_API_SECRET to run backend tests.'
      : null;

  group('Tag contract CRUD (real backend)', () {
    late TagRepository repository;
    late RpcRecorder recorder;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      recorder = RpcRecorder();
      repository = TagRepository(buildTestClient(config!, recorder));
    });

    test('create/rename/update/delete tag + goldens', () async {
      KomodoTag? created;

      try {
        final createResult = await repository.createTag(
          name: 'Contract Tag',
          color: TagColor.slate,
        );
        created = expectRight(createResult);

        final requestData = recorder.lastRequest?.data;
        final responseData = recorder.lastResponse?.data;

        expect(requestData, isA<Map>());
        expect(responseData, isA<Map>());

        final normalizedRequest = normalizeJson(
          (requestData as Map).cast<String, dynamic>(),
        );
        expect(
          normalizedRequest,
          loadGoldenJson('test/golden/tag_create_request.json'),
        );

        final normalizedResponse = normalizeTagResponse(
          (responseData as Map).cast<String, dynamic>(),
        );
        expect(
          normalizedResponse,
          loadGoldenJson('test/golden/tag_create_response.json'),
        );

        final listed = expectRight(await repository.listTags());
        expect(listed.any((t) => t.id == created!.id), isTrue);

        final renamed = expectRight(
          await repository.renameTag(
            id: created!.id,
            name: 'Contract Tag Renamed',
          ),
        );
        expect(renamed.id, created!.id);
        expect(renamed.name, 'Contract Tag Renamed');

        final afterRename = expectRight(await repository.listTags());
        final renamedFromList = afterRename.firstWhere(
          (t) => t.id == created!.id,
        );
        expect(renamedFromList.name, 'Contract Tag Renamed');

        final recolored = expectRight(
          await repository.updateTagColor(
            tagIdOrName: created!.id,
            color: TagColor.red,
          ),
        );
        expect(recolored.id, created!.id);
        expect(recolored.color, TagColor.red);

        final afterColor = expectRight(await repository.listTags());
        final recoloredFromList = afterColor.firstWhere(
          (t) => t.id == created!.id,
        );
        expect(recoloredFromList.color, TagColor.red);

        expectRight(await repository.deleteTag(id: created!.id));
        final afterDelete = expectRight(await repository.listTags());
        expect(afterDelete.any((t) => t.id == created!.id), isFalse);
      } finally {
        if (created != null) {
          await repository.deleteTag(id: created.id);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());

  group('Tag CRUD property-based (real backend)', () {
    late TagRepository repository;

    setUp(() async {
      await resetBackendIfConfigured(config!);
      repository = TagRepository(
        buildTestClient(config!, RpcRecorder()),
      );
    });

    test('randomized tags survive CRUD roundtrip', () async {
      final random = Random(1337);
      final createdIds = <String>[];

      try {
        for (var i = 0; i < 20; i++) {
          final name = 'prop-tag-$i-${_randomToken(random)}';
          final initialColor = _randomColor(random);
          final updatedColor = _randomColor(random, exclude: initialColor);

          final created = expectRight(
            await repository.createTag(name: name, color: initialColor),
          );
          createdIds.add(created.id);

          final listed = expectRight(await repository.listTags());
          final fromList = listed.firstWhere((t) => t.id == created.id);
          expect(fromList.name, name);
          expect(fromList.color, initialColor);

          final renamed = expectRight(
            await repository.renameTag(
              id: created.id,
              name: '${name}_renamed',
            ),
          );
          expect(renamed.id, created.id);
          expect(renamed.name, '${name}_renamed');

          final recolored = expectRight(
            await repository.updateTagColor(
              tagIdOrName: created.id,
              color: updatedColor,
            ),
          );
          expect(recolored.id, created.id);
          expect(recolored.color, updatedColor);

          expectRight(await repository.deleteTag(id: created.id));
          final afterDelete = expectRight(await repository.listTags());
          expect(afterDelete.any((t) => t.id == created.id), isFalse);
        }
      } finally {
        for (final id in createdIds) {
          await repository.deleteTag(id: id);
        }
      }
    });
  },
      skip: missingConfigReason ??
          config?.skipReason() ??
          config?.requireResetReason());
}

T expectRight<T>(Either<Failure, T> result) {
  return result.fold(
    (failure) => fail('Expected success, got $failure'),
    (value) => value,
  );
}

String _randomToken(Random random) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }
  return buffer.toString();
}

TagColor _randomColor(Random random, {TagColor? exclude}) {
  final colors = TagColor.values
      .where((color) => color != exclude)
      .toList(growable: false);
  return colors[random.nextInt(colors.length)];
}

Map<String, dynamic> normalizeTagResponse(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  normalized['id'] = '<id>';
  normalized['owner'] = '<owner>';
  normalized.remove('_id');
  return normalizeJson(normalized);
}
