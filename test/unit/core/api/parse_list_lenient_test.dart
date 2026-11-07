import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/api/parse_list_lenient.dart';
import 'package:komodo_go/core/error/failures.dart';
import 'package:komodo_go/features/stacks/data/models/stack.dart';

void main() {
  Map<String, dynamic> good(String id) => {
    'id': id,
    'name': id,
    'info': <String, dynamic>{},
  };

  test('all good items are returned', () {
    final r = parseListLenient(
      [good('a'), good('b')],
      StackListItem.fromJson,
      label: 'StackListItem',
    );
    expect(r.map((e) => e.id), ['a', 'b']);
  });

  test('bad items are skipped and the rest returned', () {
    final r = parseListLenient(
      [
        good('a'),
        <String, dynamic>{'id': 'bad', 'name': 5, 'info': <String, dynamic>{}},
        'not a map',
        good('c'),
      ],
      StackListItem.fromJson,
      label: 'StackListItem',
    );
    expect(r.map((e) => e.id), ['a', 'c']);
  });

  test('all bad items throw a readable ParseFailure', () {
    expect(
      () => parseListLenient(
        [
          <String, dynamic>{'id': 'x', 'name': 5, 'info': <String, dynamic>{}},
          <String, dynamic>{'id': 'y', 'name': 6, 'info': <String, dynamic>{}},
        ],
        StackListItem.fromJson,
        label: 'StackListItem',
      ),
      throwsA(
        isA<ParseFailure>().having(
          (f) => f.displayMessage,
          'message',
          contains('StackListItem.name'),
        ),
      ),
    );
  });

  test('empty list returns empty', () {
    expect(
      parseListLenient(
        const <dynamic>[],
        StackListItem.fromJson,
        label: 'StackListItem',
      ),
      isEmpty,
    );
  });
}
