import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag.freezed.dart';
part 'tag.g.dart';

enum TagColor {
  lightSlate,
  slate,
  darkSlate,
  lightRed,
  red,
  darkRed,
  lightOrange,
  orange,
  darkOrange,
  lightAmber,
  amber,
  darkAmber,
  lightYellow,
  yellow,
  darkYellow,
  lightLime,
  lime,
  darkLime,
  lightGreen,
  green,
  darkGreen,
  lightEmerald,
  emerald,
  darkEmerald,
  lightTeal,
  teal,
  darkTeal,
  lightCyan,
  cyan,
  darkCyan,
  lightSky,
  sky,
  darkSky,
  lightBlue,
  blue,
  darkBlue,
  lightIndigo,
  indigo,
  darkIndigo,
  lightViolet,
  violet,
  darkViolet,
  lightPurple,
  purple,
  darkPurple,
  lightFuchsia,
  fuchsia,
  darkFuchsia,
  lightPink,
  pink,
  darkPink,
  lightRose,
  rose,
  darkRose,
}

TagColor _tagColorFromJson(Object? value) {
  if (value is! String) return TagColor.slate;
  final normalized = value.trim().toLowerCase().replaceAll('_', '');
  return _tagColorByToken[normalized] ?? TagColor.slate;
}

String _tagColorToJson(TagColor value) => value.token;

final Map<String, TagColor> _tagColorByToken = {
  for (final c in TagColor.values) c.token.toLowerCase(): c,
};

extension TagColorX on TagColor {
  String get token {
    // Matches the Komodo backend's enum variants, e.g. "LightSlate".
    return switch (this) {
      TagColor.lightSlate => 'LightSlate',
      TagColor.slate => 'Slate',
      TagColor.darkSlate => 'DarkSlate',
      TagColor.lightRed => 'LightRed',
      TagColor.red => 'Red',
      TagColor.darkRed => 'DarkRed',
      TagColor.lightOrange => 'LightOrange',
      TagColor.orange => 'Orange',
      TagColor.darkOrange => 'DarkOrange',
      TagColor.lightAmber => 'LightAmber',
      TagColor.amber => 'Amber',
      TagColor.darkAmber => 'DarkAmber',
      TagColor.lightYellow => 'LightYellow',
      TagColor.yellow => 'Yellow',
      TagColor.darkYellow => 'DarkYellow',
      TagColor.lightLime => 'LightLime',
      TagColor.lime => 'Lime',
      TagColor.darkLime => 'DarkLime',
      TagColor.lightGreen => 'LightGreen',
      TagColor.green => 'Green',
      TagColor.darkGreen => 'DarkGreen',
      TagColor.lightEmerald => 'LightEmerald',
      TagColor.emerald => 'Emerald',
      TagColor.darkEmerald => 'DarkEmerald',
      TagColor.lightTeal => 'LightTeal',
      TagColor.teal => 'Teal',
      TagColor.darkTeal => 'DarkTeal',
      TagColor.lightCyan => 'LightCyan',
      TagColor.cyan => 'Cyan',
      TagColor.darkCyan => 'DarkCyan',
      TagColor.lightSky => 'LightSky',
      TagColor.sky => 'Sky',
      TagColor.darkSky => 'DarkSky',
      TagColor.lightBlue => 'LightBlue',
      TagColor.blue => 'Blue',
      TagColor.darkBlue => 'DarkBlue',
      TagColor.lightIndigo => 'LightIndigo',
      TagColor.indigo => 'Indigo',
      TagColor.darkIndigo => 'DarkIndigo',
      TagColor.lightViolet => 'LightViolet',
      TagColor.violet => 'Violet',
      TagColor.darkViolet => 'DarkViolet',
      TagColor.lightPurple => 'LightPurple',
      TagColor.purple => 'Purple',
      TagColor.darkPurple => 'DarkPurple',
      TagColor.lightFuchsia => 'LightFuchsia',
      TagColor.fuchsia => 'Fuchsia',
      TagColor.darkFuchsia => 'DarkFuchsia',
      TagColor.lightPink => 'LightPink',
      TagColor.pink => 'Pink',
      TagColor.darkPink => 'DarkPink',
      TagColor.lightRose => 'LightRose',
      TagColor.rose => 'Rose',
      TagColor.darkRose => 'DarkRose',
    };
  }

  String get label {
    final t = token;
    return t.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  }

  Color get swatch {
    final (Color light, Color mid, Color dark) = switch (this) {
      TagColor.lightSlate || TagColor.slate || TagColor.darkSlate => (
        Colors.blueGrey.shade300,
        Colors.blueGrey.shade500,
        Colors.blueGrey.shade800,
      ),
      TagColor.lightRed || TagColor.red || TagColor.darkRed => (
        Colors.red.shade300,
        Colors.red.shade500,
        Colors.red.shade800,
      ),
      TagColor.lightOrange || TagColor.orange || TagColor.darkOrange => (
        Colors.orange.shade300,
        Colors.orange.shade600,
        Colors.orange.shade900,
      ),
      TagColor.lightAmber || TagColor.amber || TagColor.darkAmber => (
        Colors.amber.shade300,
        Colors.amber.shade600,
        Colors.amber.shade900,
      ),
      TagColor.lightYellow || TagColor.yellow || TagColor.darkYellow => (
        Colors.yellow.shade300,
        Colors.yellow.shade600,
        Colors.yellow.shade900,
      ),
      TagColor.lightLime || TagColor.lime || TagColor.darkLime => (
        Colors.lime.shade300,
        Colors.lime.shade600,
        Colors.lime.shade900,
      ),
      TagColor.lightGreen || TagColor.green || TagColor.darkGreen => (
        Colors.green.shade300,
        Colors.green.shade600,
        Colors.green.shade900,
      ),
      TagColor.lightEmerald || TagColor.emerald || TagColor.darkEmerald => (
        Colors.teal.shade200,
        Colors.teal.shade500,
        Colors.teal.shade800,
      ),
      TagColor.lightTeal || TagColor.teal || TagColor.darkTeal => (
        Colors.teal.shade200,
        Colors.teal.shade500,
        Colors.teal.shade800,
      ),
      TagColor.lightCyan || TagColor.cyan || TagColor.darkCyan => (
        Colors.cyan.shade200,
        Colors.cyan.shade500,
        Colors.cyan.shade800,
      ),
      TagColor.lightSky || TagColor.sky || TagColor.darkSky => (
        Colors.lightBlue.shade200,
        Colors.lightBlue.shade500,
        Colors.lightBlue.shade800,
      ),
      TagColor.lightBlue || TagColor.blue || TagColor.darkBlue => (
        Colors.blue.shade200,
        Colors.blue.shade500,
        Colors.blue.shade800,
      ),
      TagColor.lightIndigo || TagColor.indigo || TagColor.darkIndigo => (
        Colors.indigo.shade200,
        Colors.indigo.shade500,
        Colors.indigo.shade800,
      ),
      TagColor.lightViolet || TagColor.violet || TagColor.darkViolet => (
        Colors.deepPurple.shade200,
        Colors.deepPurple.shade400,
        Colors.deepPurple.shade700,
      ),
      TagColor.lightPurple || TagColor.purple || TagColor.darkPurple => (
        Colors.purple.shade200,
        Colors.purple.shade500,
        Colors.purple.shade800,
      ),
      TagColor.lightFuchsia || TagColor.fuchsia || TagColor.darkFuchsia => (
        Colors.pinkAccent.shade100,
        Colors.pinkAccent.shade200,
        Colors.pinkAccent.shade400,
      ),
      TagColor.lightPink || TagColor.pink || TagColor.darkPink => (
        Colors.pink.shade200,
        Colors.pink.shade500,
        Colors.pink.shade800,
      ),
      TagColor.lightRose || TagColor.rose || TagColor.darkRose => (
        Colors.redAccent.shade100,
        Colors.redAccent.shade200,
        Colors.redAccent.shade400,
      ),
    };

    return switch (this) {
      TagColor.lightSlate ||
      TagColor.lightRed ||
      TagColor.lightOrange ||
      TagColor.lightAmber ||
      TagColor.lightYellow ||
      TagColor.lightLime ||
      TagColor.lightGreen ||
      TagColor.lightEmerald ||
      TagColor.lightTeal ||
      TagColor.lightCyan ||
      TagColor.lightSky ||
      TagColor.lightBlue ||
      TagColor.lightIndigo ||
      TagColor.lightViolet ||
      TagColor.lightPurple ||
      TagColor.lightFuchsia ||
      TagColor.lightPink ||
      TagColor.lightRose => light,
      TagColor.darkSlate ||
      TagColor.darkRed ||
      TagColor.darkOrange ||
      TagColor.darkAmber ||
      TagColor.darkYellow ||
      TagColor.darkLime ||
      TagColor.darkGreen ||
      TagColor.darkEmerald ||
      TagColor.darkTeal ||
      TagColor.darkCyan ||
      TagColor.darkSky ||
      TagColor.darkBlue ||
      TagColor.darkIndigo ||
      TagColor.darkViolet ||
      TagColor.darkPurple ||
      TagColor.darkFuchsia ||
      TagColor.darkPink ||
      TagColor.darkRose => dark,
      _ => mid,
    };
  }
}

@freezed
sealed class KomodoTag with _$KomodoTag {
  const factory KomodoTag({
    @JsonKey(readValue: _readId) required String id,
    required String name,
    required String owner,
    @JsonKey(fromJson: _tagColorFromJson, toJson: _tagColorToJson)
    required TagColor color,
  }) = _KomodoTag;

  factory KomodoTag.fromJson(Map<String, dynamic> json) =>
      _$KomodoTagFromJson(json);
}

/// Reads the id from either 'id' or '_id.$oid' format.
Object? _readId(Map<dynamic, dynamic> json, String key) {
  if (json.containsKey('id')) {
    return json['id'];
  }
  if (json.containsKey('_id')) {
    final id = json['_id'];
    if (id is Map && id.containsKey(r'$oid')) {
      return id[r'$oid'];
    }
    return id;
  }
  return null;
}

