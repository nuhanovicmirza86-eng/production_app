import 'package:flutter/material.dart';

/// UX-M2-A — guarded data-entry dialogs (Production app).
Future<T?> showGuardedDataEntryDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  Color? barrierColor,
  String? barrierLabel,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: useRootNavigator,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: builder(dialogContext),
      );
    },
  );
}
