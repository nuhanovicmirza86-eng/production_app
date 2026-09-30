import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/core/ui/standard_list_components.dart';
import 'package:production_app/modules/production/ai/widgets/operonix_ai_assistant_conversation_layout.dart';
import 'package:production_app/modules/production/ai/widgets/operonix_ai_chat_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tracking assistant screen uses scrollable conversation layout', () {
    final src = File(
      'lib/modules/production/ai/screens/production_tracking_assistant_screen.dart',
    ).readAsStringSync();
    expect(src.contains('OperonixAiAssistantConversationLayout'), isTrue);
    final layout = File(
      'lib/modules/production/ai/widgets/operonix_ai_assistant_conversation_layout.dart',
    ).readAsStringSync();
    expect(layout.contains('Doseg asistenta'), isTrue);
  });

  testWidgets('scope is inside ListView, not pinned above conversation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var expanded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OperonixAiAssistantConversationLayout(
                showScope: true,
                scopeExpanded: expanded,
                scopeSummary: 'Svi pogoni (cijela tvrtka)',
                onToggleScope: () => setState(() => expanded = !expanded),
                scopeControls: const Text('Odaberi pogon'),
                conversation: [
                  for (var i = 0; i < 40; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Odgovor linija $i'),
                    ),
                ],
                composer: OperonixAiChatComposer(
                  controller: controller,
                  onSend: () {},
                ),
              );
            },
          ),
        ),
      ),
    );

    final listView = find.byType(ListView);
    expect(listView, findsOneWidget);
    expect(
      find.descendant(of: listView, matching: find.text('Doseg asistenta')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: listView,
        matching: find.text('Svi pogoni (cijela tvrtka)'),
      ),
      findsOneWidget,
    );
    expect(find.byType(StandardFilterPanel), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.text('Pošalji'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byIcon(Icons.send), findsOneWidget);

    final field = tester.getRect(find.byType(TextField));
    final send = tester.getRect(find.byType(IconButton));
    expect(send.left, greaterThan(field.right));

    await tester.tap(find.text('Doseg asistenta'));
    await tester.pumpAndSettle();
    expect(find.text('Odaberi pogon'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

    await tester.drag(listView, const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.text('Pošalji'), findsNothing);
    expect(find.textContaining('Odgovor linija'), findsWidgets);
  });
}
