import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'containers_filters_provider.g.dart';

enum ContainersSortField { name, cpu, memory, network, blockIo, pids }

class ContainersSortState {
  const ContainersSortState({required this.field, required this.descending});

  final ContainersSortField field;
  final bool descending;

  ContainersSortState copyWith({ContainersSortField? field, bool? descending}) {
    return ContainersSortState(
      field: field ?? this.field,
      descending: descending ?? this.descending,
    );
  }
}

@riverpod
class ContainersSearchQuery extends _$ContainersSearchQuery {
  @override
  String build() => '';

  String get query => state;

  set query(String value) => state = value;
}

@riverpod
class ContainersServerFilter extends _$ContainersServerFilter {
  @override
  String? build() => null;

  String? get serverId => state;

  set serverId(String? value) => state = value;
}

@riverpod
class ContainersSort extends _$ContainersSort {
  @override
  ContainersSortState build() {
    return const ContainersSortState(
      field: ContainersSortField.name,
      descending: false,
    );
  }

  ContainersSortField get field => state.field;

  set field(ContainersSortField value) {
    if (state.field == value) return;
    state = state.copyWith(
      field: value,
      descending: switch (value) {
        ContainersSortField.name => false,
        _ => true,
      },
    );
  }

  void toggleDirection() {
    state = state.copyWith(descending: !state.descending);
  }
}
