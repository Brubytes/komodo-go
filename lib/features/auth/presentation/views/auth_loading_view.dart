import 'package:flutter/material.dart';

class AuthLoadingView extends StatelessWidget {
  const AuthLoadingView({super.key});

  static const loadingKey = Key('auth_loading_view');

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          key: loadingKey,
          child: SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}
