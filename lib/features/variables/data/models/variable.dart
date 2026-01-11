import 'package:freezed_annotation/freezed_annotation.dart';

part 'variable.freezed.dart';
part 'variable.g.dart';

@freezed
sealed class KomodoVariable with _$KomodoVariable {
  const factory KomodoVariable({
    required String name,
    @Default('') String description,
    @Default('') String value,
    @JsonKey(name: 'is_secret') @Default(false) bool isSecret,
  }) = _KomodoVariable;

  factory KomodoVariable.fromJson(Map<String, dynamic> json) =>
      _$KomodoVariableFromJson(json);
}
