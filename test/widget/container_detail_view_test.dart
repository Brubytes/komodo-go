import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:komodo_go/composition/containers/containers_provider.dart';
import 'package:komodo_go/features/containers/data/models/container.dart';
import 'package:komodo_go/features/containers/data/repositories/container_repository.dart';
import 'package:komodo_go/features/containers/presentation/views/container_detail_view.dart';

class _TestContainers extends Containers {
  _TestContainers(this._resultBuilder);

  final ContainersResult Function() _resultBuilder;

  @override
  Future<ContainersResult> build() async => _resultBuilder();
}

ContainerOverviewItem _item({required String image}) {
  return ContainerOverviewItem(
    serverId: 'srv-1',
    serverName: 'Server One',
    container: ContainerListItem(
      serverId: 'srv-1',
      id: 'c1',
      name: 'web',
      image: image,
      state: ContainerState.running,
    ),
  );
}

void main() {
  testWidgets('pull-to-refresh shows fresh container data', (tester) async {
    var image = 'nginx:1';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          containersProvider.overrideWith(
            () => _TestContainers(
              () => ContainersResult(
                items: [_item(image: image)],
                errors: [],
              ),
            ),
          ),
          containerRepositoryProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          home: ContainerDetailView(
            serverId: 'srv-1',
            containerIdOrName: 'web',
            initialItem: _item(image: image),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('nginx:1'), findsOneWidget);

    // The backend now reports a different image; pull-to-refresh must show it.
    image = 'nginx:2';
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('nginx:2'), findsOneWidget);
    expect(find.text('nginx:1'), findsNothing);
  });
}
