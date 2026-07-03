import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/resources/resource_tag_options_provider.dart';
import 'package:komodo_go/features/tags/data/models/tag.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

class _TestTags extends Tags {
  _TestTags(this._tags);

  final List<KomodoTag> _tags;

  @override
  Future<List<KomodoTag>> build() async => _tags;
}

void main() {
  test('resource tag options trim names and omit blank tags', () async {
    final container = ProviderContainer(
      overrides: [
        tagsProvider.overrideWith(
          () => _TestTags(
            const [
              KomodoTag(
                id: 'tag-1',
                name: '  Production ',
                owner: 'user',
                color: TagColor.blue,
              ),
              KomodoTag(
                id: 'tag-2',
                name: ' ',
                owner: 'user',
                color: TagColor.red,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(resourceTagOptionsProvider, (_, _) {});
    await container.read(tagsProvider.future);

    final options = container.read(resourceTagOptionsProvider).requireValue;

    expect(options, hasLength(1));
    expect(options.single.id, 'tag-1');
    expect(options.single.name, 'Production');
  });
}
