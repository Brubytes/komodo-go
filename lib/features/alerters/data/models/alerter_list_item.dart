import 'package:freezed_annotation/freezed_annotation.dart';

part 'alerter_list_item.freezed.dart';
part 'alerter_list_item.g.dart';

@freezed
sealed class AlerterListItemInfo with _$AlerterListItemInfo {
  const factory AlerterListItemInfo({
    @Default(false) bool enabled,
    @JsonKey(name: 'endpoint_type') @Default('Custom') String endpointType,
  }) = _AlerterListItemInfo;

  factory AlerterListItemInfo.fromJson(Map<String, dynamic> json) =>
      _$AlerterListItemInfoFromJson(json);
}

@freezed
sealed class AlerterListItem with _$AlerterListItem {
  const factory AlerterListItem({
    required String id,
    required String name,
    required AlerterListItemInfo info,
    @Default(false) bool template,
    @Default(<String>[]) List<String> tags,
  }) = _AlerterListItem;

  factory AlerterListItem.fromJson(Map<String, dynamic> json) =>
      _$AlerterListItemFromJson(json);
}
