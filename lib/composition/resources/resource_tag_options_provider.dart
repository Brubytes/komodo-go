import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/core/widgets/filters/tag_filter_sheet.dart';
import 'package:komodo_go/features/tags/presentation/providers/tags_provider.dart';

final resourceTagOptionsProvider = Provider<AsyncValue<List<TagOption>>>((ref) {
  return ref
      .watch(tagsProvider)
      .whenData(
        (tags) => [
          for (final tag in tags)
            if (tag.name.trim().isNotEmpty)
              TagOption(id: tag.id, name: tag.name.trim()),
        ],
      );
});
