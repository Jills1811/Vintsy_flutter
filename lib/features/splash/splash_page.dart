import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Simple splash delay then navigate to sign in (will later check auth state)
    scheduleMicrotask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      context.go('/signin');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: FlutterLogo(size: 96),
      ),
    );
  }
}


