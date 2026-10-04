import 'package:flutter/material.dart';

/// Viewport okvir aplikacije.
///
/// Web shell koristi cijelu širinu browsera. Nema centered max-width omotača.
class OperonixApplicationFrame extends StatelessWidget {
  final Widget child;

  /// `true` na Flutter webu. Testovi mogu uključiti isti shell bez `kIsWeb`.
  final bool useWebShell;

  const OperonixApplicationFrame({
    super.key,
    required this.child,
    required this.useWebShell,
  });

  @override
  Widget build(BuildContext context) {
    if (!useWebShell) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}
