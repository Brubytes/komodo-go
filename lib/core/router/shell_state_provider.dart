import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_state_provider.g.dart';

@riverpod
class MainShellIndex extends _$MainShellIndex {
  @override
  int build() => 0;

  int get index => state;

  set index(int value) => state = value;
}
