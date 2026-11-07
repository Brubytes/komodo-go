import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';

class StackMessageSurface extends StatelessWidget {
  const StackMessageSurface({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
