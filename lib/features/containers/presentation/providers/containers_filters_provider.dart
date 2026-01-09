import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'containers_filters_provider.g.dart';

enum ContainersSortField { name, cpu, memory, network, blockIo, pids }

class ContainersSortState {
  const ContainersSortState({
    required this.field,
    required this.descending,
  });

  final ContainersSortField field;
  final bool descending;

  ContainersSortState copyWith({
    ContainersSortField? field,
    bool? descending,
  }) {
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

  void setQuery(String value) => state = value;
}

@riverpod
class ContainersServerFilter extends _$ContainersServerFilter {
  @override
  String? build() => null;

  void setServerId(String? value) => state = value;
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

  void setField(ContainersSortField field) {
    if (state.field == field) return;
    state = state.copyWith(
      field: field,
      descending: switch (field) {
        ContainersSortField.name => false,
        _ => true,
      },
    );
  }

  void toggleDirection() {
    state = state.copyWith(descending: !state.descending);
  }
}
