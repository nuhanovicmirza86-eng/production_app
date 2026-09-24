import 'package:flutter/material.dart';

import '../../../../core/branding/operonix_ai_branding.dart';
import '../../../../core/saas/production_module_keys.dart';
import '../models/operonix_ai_entity_chat_binding.dart';
import '../screens/production_ai_chat_screen.dart';

/// AI-M2-G3 — otvaranje postojećeg Asistent chata s entity context bindingom.
class OperonixAiAssistantNavigator {
  OperonixAiAssistantNavigator._();

  static const String askActionTooltip = 'Pitaj Operonix AI Asistenta';

  static bool canOpenAssistant(Map<String, dynamic> companyData) {
    return ProductionModuleKeys.hasAiAssistantModule(companyData);
  }

  static void openChat(
    BuildContext context, {
    required Map<String, dynamic> companyData,
    OperonixAiEntityChatBinding? entityBinding,
    bool autoAskWithBinding = true,
  }) {
    if (!canOpenAssistant(companyData)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Operonix AI Asistent nije uključen u pretplati ove tvrtke.',
          ),
        ),
      );
      return;
    }

    final binding =
        (entityBinding != null && entityBinding.isReady) ? entityBinding : null;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductionAiChatScreen(
          companyData: companyData,
          entityBinding: binding,
          autoAskWithBinding: autoAskWithBinding && binding != null,
        ),
      ),
    );
  }
}

/// Diskretna AppBar akcija — jedan Asistent, bez novog AI huba.
class OperonixAiAskAssistantAppBarAction extends StatelessWidget {
  const OperonixAiAskAssistantAppBarAction({
    super.key,
    required this.companyData,
    required this.entityBinding,
    this.autoAskWithBinding = true,
  });

  final Map<String, dynamic> companyData;
  final OperonixAiEntityChatBinding? entityBinding;
  final bool autoAskWithBinding;

  @override
  Widget build(BuildContext context) {
    if (!OperonixAiAssistantNavigator.canOpenAssistant(companyData)) {
      return const SizedBox.shrink();
    }
    final ready = entityBinding != null && entityBinding!.isReady;
    return IconButton(
      tooltip: OperonixAiAssistantNavigator.askActionTooltip,
      onPressed: !ready
          ? null
          : () => OperonixAiAssistantNavigator.openChat(
                context,
                companyData: companyData,
                entityBinding: entityBinding,
                autoAskWithBinding: autoAskWithBinding,
              ),
      icon: const Icon(Icons.auto_awesome_outlined),
    );
  }
}

/// Kratki kontekst chip u chatu (samo displayLabel).
class OperonixAiEntityContextChip extends StatelessWidget {
  const OperonixAiEntityContextChip({
    super.key,
    required this.binding,
  });

  final OperonixAiEntityChatBinding binding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Icon(
              Icons.link_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    binding.contextChipTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    binding.displayLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    kOperonixAiAssistantProductName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
