import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/scaffold_messenger_key.dart';
import 'core/theme/fletar_theme.dart';

class FletarApp extends ConsumerWidget {
  const FletarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FletAR',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: FletarTheme.light(),
      routerConfig: router,
    );
  }
}
