import 'package:flutter/material.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';
import 'package:komodo_go/core/widgets/loading/app_skeleton.dart';

class StackLoadingSurface extends StatelessWidget {
  const StackLoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSkeletonSurface();
  }
}

class StackMessageSurface extends StatelessWidget {
  const StackMessageSurface({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DetailSurface(child: Text(message));
  }
}
