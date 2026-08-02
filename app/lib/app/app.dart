import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import 'app_theme.dart';
import 'routing/app_router.dart';

class WhichOneApp extends StatelessWidget {
  const WhichOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
