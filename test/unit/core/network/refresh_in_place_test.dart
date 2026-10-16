import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/network/refresh_in_place.dart';

void main() {
  test(
    'does not apply when the fetched value equals the current one',
    () async {
      var applied = 0;
      final changed = await refreshInPlace<List<int>>(
        current: [1, 2],
        fetch: () async => [1, 2],
        apply: (_) => applied++,
        equals: listEq,
      );
      expect(changed, isFalse);
      expect(applied, 0);
    },
  );

  test('applies when the value differs', () async {
    List<int>? applied;
    final changed = await refreshInPlace<List<int>>(
      current: [1, 2],
      fetch: () async => [1, 3],
      apply: (v) => applied = v,
      equals: listEq,
    );
    expect(changed, isTrue);
    expect(applied, [1, 3]);
  });

  test('applies when there is no current value', () async {
    int? applied;
    await refreshInPlace<int>(
      current: null,
      fetch: () async => 1,
      apply: (v) => applied = v,
    );
    expect(applied, 1);
  });

  test('swallows fetch errors and keeps the previous value', () async {
    var applied = 0;
    final changed = await refreshInPlace<int>(
      current: 1,
      fetch: () async => throw Exception('offline'),
      apply: (_) => applied++,
    );
    expect(changed, isFalse);
    expect(applied, 0);
  });

  test('does not apply after unmount', () async {
    var applied = 0;
    await refreshInPlace<int>(
      current: 1,
      fetch: () async => 2,
      apply: (_) => applied++,
      isMounted: () => false,
    );
    expect(applied, 0);
  });
}
