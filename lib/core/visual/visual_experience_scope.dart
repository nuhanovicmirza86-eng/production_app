import 'package:flutter/widgets.dart';

import 'visual_experience_controller.dart';

class VisualExperienceScope
    extends InheritedNotifier<VisualExperienceController> {
  const VisualExperienceScope({
    super.key,
    required VisualExperienceController controller,
    required super.child,
  }) : super(notifier: controller);

  static VisualExperienceController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VisualExperienceScope>()
        ?.notifier;
  }

  static VisualExperienceController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'VisualExperienceScope nije u stablu.');
    return controller!;
  }
}
