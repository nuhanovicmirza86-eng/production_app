import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';
import 'modules/auth/session/screens/auth_wrapper.dart';

bool get _isDesktopNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktopNative) {
    await windowManager.ensureInitialized();
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF164344);

    return MaterialApp(
      title: 'Operonix Production',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        useMaterial3: true,
        visualDensity: kIsWeb ? VisualDensity.compact : VisualDensity.standard,
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        if (!kIsWeb) return child;
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: child,
            ),
          ),
        );
      },
      home: const AuthWrapper(),
    );
  }
}
