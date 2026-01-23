import 'package:flutter/material.dart';

import 'package:komodo_go/core/theme/app_tokens.dart';

InputDecoration _decorationWithoutSubText(
  InputDecoration decoration, {
  required bool enabled,
}) {
  // NOTE: InputDecoration.copyWith cannot "clear" fields like helperText/
  // errorText because `null` means "keep existing". We must create a new
  // InputDecoration instead.
  return InputDecoration(
    icon: decoration.icon,
    iconColor: decoration.iconColor,
    labelText: decoration.labelText,
    labelStyle: decoration.labelStyle,
    floatingLabelStyle: decoration.floatingLabelStyle,
    helper: null,
    helperText: null,
    hintText: decoration.hintText,
    hintStyle: decoration.hintStyle,
    hintTextDirection: decoration.hintTextDirection,
    hintMaxLines: decoration.hintMaxLines,
    error: null,
    errorText: null,
    floatingLabelBehavior: decoration.floatingLabelBehavior,
    floatingLabelAlignment: decoration.floatingLabelAlignment,
    isDense: decoration.isDense,
    contentPadding: decoration.contentPadding,
    prefixIcon: decoration.prefixIcon,
    prefixIconConstraints: decoration.prefixIconConstraints,
    prefix: decoration.prefix,
    prefixText: decoration.prefixText,
    prefixStyle: decoration.prefixStyle,
    prefixIconColor: decoration.prefixIconColor,
    suffixIcon: decoration.suffixIcon,
    suffixIconConstraints: decoration.suffixIconConstraints,
    suffix: decoration.suffix,
    suffixText: decoration.suffixText,
    suffixStyle: decoration.suffixStyle,
    suffixIconColor: decoration.suffixIconColor,
    counter: null,
    counterText: null,
    filled: decoration.filled,
    fillColor: decoration.fillColor,
    focusColor: decoration.focusColor,
    hoverColor: decoration.hoverColor,
    errorBorder: decoration.errorBorder,
    focusedBorder: decoration.focusedBorder,
    focusedErrorBorder: decoration.focusedErrorBorder,
    disabledBorder: decoration.disabledBorder,
    enabledBorder: decoration.enabledBorder,
    border: decoration.border,
    enabled: enabled,
    semanticCounterText: decoration.semanticCounterText,
    alignLabelWithHint: decoration.alignLabelWithHint,
    constraints: decoration.constraints,
  );
}

class KomodoSelectMenuItem<T> {
  const KomodoSelectMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;
}

/// An input-like select field that uses a popup menu for selection.
///
/// This avoids the default Material dropdown route (square corners) and reuses
/// the app's `popupMenuTheme` styling.
class KomodoSelectMenuField<T> extends StatelessWidget {
  const KomodoSelectMenuField({
    required this.items,
    required this.decoration,
    this.value,
    this.onChanged,
    this.enabled = true,
    this.hintText,
    this.menuMaxHeight,
    super.key,
  });

  final T? value;
  final List<KomodoSelectMenuItem<T>> items;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final String? hintText;
  final double? menuMaxHeight;

  static const _rowHPadding = 16.0;
  static const _rowVPadding = 12.0;
  static const _iconBoxRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final selected = _selectedItem();

    final effectiveEnabled = enabled && onChanged != null;

    final labelStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: effectiveEnabled
          ? scheme.onSurface
          : scheme.onSurfaceVariant.withValues(alpha: 0.65),
      fontWeight: FontWeight.w600,
    );

    final displayText =
        selected?.label ?? hintText ?? decoration.hintText ?? '';

    // Apply theme defaults first so the rebuilt decoration preserves the
    // project's InputDecorationTheme styling.
    final baseDecoration = decoration.applyDefaults(theme.inputDecorationTheme);
    final effectiveDecoration = _decorationWithoutSubText(
      baseDecoration,
      enabled: effectiveEnabled,
    );

    final subTextWidget = decoration.error ?? decoration.helper;
    final subText = decoration.errorText ?? decoration.helperText;
    final hasSubTextWidget = subTextWidget != null;
    final hasSubText = subText != null && subText.trim().isNotEmpty;
    final showError = (decoration.error ?? decoration.errorText) != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (fieldContext) {
            return Semantics(
              button: true,
              enabled: effectiveEnabled,
              child: InkWell(
                onTap: effectiveEnabled ? () => _openMenu(fieldContext) : null,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: InputDecorator(
                  decoration: effectiveDecoration,
                  isEmpty: selected == null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayText,
                          style: labelStyle,
                          maxLines: 1,
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (hasSubTextWidget || hasSubText)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 6),
            child: DefaultTextStyle(
              style:
                  (showError
                      ? theme.inputDecorationTheme.errorStyle
                      : theme.inputDecorationTheme.helperStyle) ??
                  theme.textTheme.bodySmall!.copyWith(
                    color: showError ? scheme.error : scheme.onSurfaceVariant,
                  ),
              child: subTextWidget ?? Text(subText!),
            ),
          ),
      ],
    );
  }

  KomodoSelectMenuItem<T>? _selectedItem() {
    final currentValue = value;
    for (final item in items) {
      if (item.value == currentValue) return item;
    }
    return null;
  }

  Future<void> _openMenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    if (renderBox == null || overlay == null) return;

    final rect = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero, ancestor: overlay),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );

    final selectedItem = await _showAnchoredMenu(
      context: context,
      fieldRect: rect,
      overlaySize: overlay.size,
      width: renderBox.size.width,
      maxHeight: menuMaxHeight ?? 360,
    );

    if (!context.mounted) return;
    if (selectedItem == null) return;

    onChanged?.call(selectedItem.value);
  }

  Future<KomodoSelectMenuItem<T>?> _showAnchoredMenu({
    required BuildContext context,
    required Rect fieldRect,
    required Size overlaySize,
    required double width,
    required double maxHeight,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final popupTheme = theme.popupMenuTheme;
    final currentValue = value;

    // Prefer opening below the field, fall back to above when space is tight.
    final availableBelow = overlaySize.height - fieldRect.bottom;
    final openDown = availableBelow >= 220;

    final left = fieldRect.left.clamp(0.0, overlaySize.width - width);

    // Rough estimate for positioning when opening upwards.
    final estimatedHeight = (items.length * 48.0).clamp(0.0, maxHeight);
    final top = openDown
        ? fieldRect.bottom
        : (fieldRect.top - estimatedHeight).clamp(
            0.0,
            overlaySize.height - estimatedHeight,
          );

    return showGeneralDialog<KomodoSelectMenuItem<T>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curve),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              child: Material(
                color: popupTheme.color ?? scheme.surface,
                elevation: popupTheme.elevation ?? 0,
                shadowColor: popupTheme.shadowColor,
                surfaceTintColor: popupTheme.surfaceTintColor,
                shape: popupTheme.shape,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      final isSelected = item.value == currentValue;
                      final isDestructive = item.isDestructive;

                      // Selected row is a solid secondary fill (no border, no
                      // per-row rounding). Overall rounding comes from
                      // popupTheme.shape + clip.
                      final rowBackground = isSelected
                          ? (isDestructive ? scheme.error : scheme.secondary)
                          : Colors.transparent;

                      final accent = isDestructive
                          ? scheme.error
                          : (isSelected
                                ? scheme.onSecondary
                                : (item.iconColor ?? scheme.primary));

                      final labelColor = isDestructive
                          ? scheme.error
                          : (isSelected
                                ? scheme.onSecondary
                                : scheme.onSurface);

                      return Material(
                        color: rowBackground,
                        child: InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: _rowHPadding,
                              vertical: _rowVPadding,
                            ),
                            child: Row(
                              children: [
                                if (item.icon != null) ...[
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                        _iconBoxRadius,
                                      ),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 18,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: labelColor,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.check, size: 18, color: accent),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// FormField wrapper around [KomodoSelectMenuField].
///
/// Use this as a drop-in replacement for `DropdownButtonFormField`.
class KomodoSelectMenuFormField<T> extends FormField<T> {
  KomodoSelectMenuFormField({
    super.key,
    required this.items,
    required this.decoration,
    this.onChanged,
    this.hintText,
    this.menuMaxHeight,
    T? initialValue,
    bool enabled = true,
    AutovalidateMode? autovalidateMode,
    FormFieldValidator<T>? validator,
    FormFieldSetter<T>? onSaved,
  }) : super(
         initialValue: initialValue,
         enabled: enabled,
         autovalidateMode: autovalidateMode,
         validator: validator,
         onSaved: onSaved,
         builder: (state) {
           final effectiveOnChanged =
               (state.widget.enabled && onChanged != null)
               ? (T? v) {
                   state.didChange(v);
                   onChanged.call(v);
                 }
               : null;

           return KomodoSelectMenuField<T>(
             value: state.value,
             items: items,
             hintText: hintText,
             menuMaxHeight: menuMaxHeight,
             enabled: state.widget.enabled,
             decoration: decoration.copyWith(errorText: state.errorText),
             onChanged: effectiveOnChanged,
           );
         },
       );

  final List<KomodoSelectMenuItem<T>> items;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final double? menuMaxHeight;
}
