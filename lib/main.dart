import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
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

    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      useMaterial3: true,
      visualDensity: kIsWeb ? VisualDensity.compact : VisualDensity.standard,
    );
    final scheme = baseTheme.colorScheme;

    return MaterialApp(
      title: 'Operonix Production',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          shape: kOperonixProductionCardShape,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: kOperonixProductionBrandGreen.withValues(alpha: 0.45),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: kOperonixProductionBrandGreen,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: scheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: scheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: scheme.error, width: 2),
          ),
        ),
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
