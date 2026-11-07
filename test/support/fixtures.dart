import 'dart:convert';
import 'dart:io';

/// Loads a captured Komodo response from `test/fixtures/komodo_2_3/`.
Map<String, dynamic> loadKomodoFixture(String name) {
  final file = File('test/fixtures/komodo_2_3/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
