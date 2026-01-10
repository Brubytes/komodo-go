import 'package:freezed_annotation/freezed_annotation.dart';

part 'builder_list_item.freezed.dart';
part 'builder_list_item.g.dart';

@freezed
sealed class BuilderListItemInfo with _$BuilderListItemInfo {
  const factory BuilderListItemInfo({
    @JsonKey(name: 'builder_type') @Default('') String builderType,
    @JsonKey(name: 'instance_type') String? instanceType,
  }) = _BuilderListItemInfo;

  factory BuilderListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$BuilderListItemInfoFromJson(json);
}

@freezed
sealed class BuilderListItem with _$BuilderListItem {
  const factory BuilderListItem({
    required String id,
    required String name,
    required BuilderListItemInfo info, @Default(false) bool template,
    @Default(<String>[]) List<String> tags,
  }) = _BuilderListItem;

  factory BuilderListItem.fromJson(Map<String, dynamic> json) =>
      _$BuilderListItemFromJson(json);
}

