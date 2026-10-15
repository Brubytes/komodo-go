import 'package:flutter/material.dart';

/// An [ExpansionTile] that cannot collide with ancestor or descendant scroll
/// positions in [PageStorage].
///
/// `Expansible` stores its expanded flag under an identifier derived from the
/// enclosing `PageStorageKey`s. Tab bodies are keyed (`PageStorageKey`) and
/// store a scroll offset (double) under that same identifier, so an unkeyed
/// tile inside would read a double as `bool?` and crash (and a keyed tile
/// would hand its bool to unkeyed scrollables in its body). This wrapper gives
/// the tile and its children their own private buckets.
class IsolatedExpansionTile extends StatefulWidget {
  const IsolatedExpansionTile({
    required this.title,
    required this.children,
    super.key,
    this.tileKey,
    this.leading,
    this.subtitle,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.tilePadding,
    this.childrenPadding,
  });

  /// Key forwarded to the inner [ExpansionTile].
  final Key? tileKey;
  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry? tilePadding;
  final EdgeInsetsGeometry? childrenPadding;
  final List<Widget> children;

  @override
  State<IsolatedExpansionTile> createState() => _IsolatedExpansionTileState();
}

class _IsolatedExpansionTileState extends State<IsolatedExpansionTile> {
  final _tileBucket = PageStorageBucket();
  final _childBucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    return PageStorage(
      bucket: _tileBucket,
      child: ExpansionTile(
        key: widget.tileKey,
        leading: widget.leading,
        title: widget.title,
        subtitle: widget.subtitle,
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: widget.onExpansionChanged,
        tilePadding: widget.tilePadding,
        childrenPadding: widget.childrenPadding,
        children: [
          PageStorage(
            bucket: _childBucket,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.children,
            ),
          ),
        ],
      ),
    );
  }
}
