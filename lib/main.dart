import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config.dart';
import 'features/installation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: AppConfig.fromEnvironment().useFakeServices
          ? const SysKataApp()
          : const InstallationApp(),
    ),
  );
}
