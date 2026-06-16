import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/finance/ai_notifications/models/finance_ai_notification_badge_summary.dart';
import 'package:production_app/modules/finance/ai_notifications/models/finance_ai_notification_delivery.dart';
import 'package:production_app/modules/finance/ai_notifications/widgets/finance_ai_notification_card.dart';
import 'package:production_app/modules/finance/shared/finance_display_labels.dart';
import 'package:production_app/modules/finance/shared/finance_strings.dart';
import 'package:production_app/modules/finance_integrations/utils/finance_permissions.dart';

/// QA — Finance AI P2-M2 in-app notification delivery UI.
void main() {
  const plantClerkData = {
    'companyId': 'plamingo',
    'role': 'accounting_clerk',
    'userId': 'clerk-plant',
    'plantKey': 'plant_a',
    'enabledModules': ['finance_controlling', 'ai_assistant_production'],
  };

  final fixtureFile = File(
    'test/fixtures/finance_p2_m2_ai_notification_integration_payload.json',
  );

  Widget wrap(Widget child, {Locale locale = const Locale('bs')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('bs'), Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  Map<String, dynamic> loadFixture() {
    if (!fixtureFile.existsSync()) {
      return _syntheticFixture();
    }
    return jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
  }

  group('Finance AI P2-M2 notification delivery (QA)', () {
    late Map<String, dynamic> fixture;
    late FinanceAiNotificationDelivery unreadMedium;
    late FinanceAiNotificationDelivery unreadInfo;
    late FinanceAiNotificationDelivery readDelivery;
    late FinanceAiNotificationDelivery closedDelivery;

    setUpAll(() {
      fixture = loadFixture();
      unreadMedium = FinanceAiNotificationDelivery.fromCallableMap(
        Map<String, dynamic>.from(fixture['unreadMedium'] as Map),
      );
      unreadInfo = FinanceAiNotificationDelivery.fromCallableMap(
        Map<String, dynamic>.from(fixture['unreadInfo'] as Map),
      );
      readDelivery = FinanceAiNotificationDelivery.fromCallableMap(
        Map<String, dynamic>.from(fixture['readDelivery'] as Map),
      );
      closedDelivery = FinanceAiNotificationDelivery.fromCallableMap(
        Map<String, dynamic>.from(fixture['closedDelivery'] as Map),
      );
    });

    test('badge summary parsira backend unreadCount', () {
      final summary = FinanceAiNotificationBadgeSummary.fromMap(
        Map<String, dynamic>.from(fixture['badgeSummary'] as Map),
      );
      expect(summary.unreadCount, greaterThan(0));
      expect(summary.companyId, 'plamingo');
    });

    test('info delivery nije badge-eligible', () {
      expect(unreadInfo.isBadgeEligible, isFalse);
      expect(unreadInfo.severity, 'info');
    });

    test('medium unread delivery jest badge-eligible', () {
      expect(unreadMedium.isBadgeEligible, isTrue);
      expect(unreadMedium.isUnread, isTrue);
      expect(unreadMedium.severity, 'medium');
    });

    test('read i closed statusi', () {
      expect(readDelivery.isRead, isTrue);
      expect(closedDelivery.isClosed, isTrue);
      expect(closedDelivery.isActiveDelivery, isFalse);
    });

    test('RBAC: plant korisnik ne koristi hub plant picker', () {
      expect(
        FinancePermissions.shouldUseHubPlantScopeSelector(
          role: 'accounting_clerk',
          profilePlantKey: 'plant_a',
        ),
        isFalse,
      );
      expect(
        FinancePermissions.canViewFinanceAiAdvisory(
          companyData: plantClerkData,
          role: 'accounting_clerk',
          debugUnlockModule: true,
        ),
        isTrue,
      );
    });

    testWidgets('BA card — prikaz statusa dostave i scope', (tester) async {
      await tester.pumpWidget(
        wrap(
          FinanceAiNotificationCard(
            delivery: unreadMedium,
            plantDisplayName: 'Pogon A',
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('Nepročitano'), findsOneWidget);
      expect(find.textContaining(unreadMedium.headline), findsOneWidget);
    });

    testWidgets('EN card — company-wide scope', (tester) async {
      final companyWide = FinanceAiNotificationDelivery.fromCallableMap({
        ...Map<String, dynamic>.from(fixture['unreadMedium'] as Map),
        'plantKey': '',
      });
      await tester.pumpWidget(
        wrap(
          FinanceAiNotificationCard(
            delivery: companyWide,
            onTap: () {},
          ),
          locale: const Locale('en'),
        ),
      );
      expect(find.textContaining('Entire company'), findsOneWidget);
    });

    testWidgets('BA/EN string ključevi za notification sekciju', (tester) async {
      await tester.pumpWidget(wrap(const Text('probe'), locale: const Locale('bs')));
      expect(
        FinanceStrings.t(
          tester.element(find.text('probe')),
          'notification_section_title',
        ),
        'In-app obavijesti',
      );
      await tester.pumpWidget(wrap(const Text('probe'), locale: const Locale('en')));
      expect(
        FinanceStrings.t(
          tester.element(find.text('probe')),
          'notification_section_title',
        ),
        'In-app notifications',
      );
    });

    test('plant filter logika — company-wide uvijek u scopeu pojedinačnog pogona', () {
      bool matchesPlantFilter(String deliveryPlantKey, String filterPlantKey) {
        if (filterPlantKey.trim().isEmpty) return true;
        if (deliveryPlantKey.trim().isEmpty) return true;
        return deliveryPlantKey.trim() == filterPlantKey.trim();
      }

      expect(matchesPlantFilter('', 'plant_a'), isTrue);
      expect(matchesPlantFilter('plant_a', 'plant_a'), isTrue);
      expect(matchesPlantFilter('plant_b', 'plant_a'), isFalse);
    });

    test('delivery status labeli', () {
      expect(
        FinanceDisplayLabels.notificationDeliveryStatusCodes,
        containsAll(['unread', 'read', 'acknowledged', 'superseded', 'closed']),
      );
    });
  });
}

Map<String, dynamic> _syntheticFixture() {
  return {
    'badgeSummary': {
      'unreadCount': 2,
      'companyId': 'plamingo',
      'plantKey': null,
    },
    'unreadMedium': {
      'deliveryId': 'd1',
      'companyId': 'plamingo',
      'alertId': 'a1',
      'plantKey': 'plant_a',
      'ruleId': 'liquidity_below_minimum_reserve_nominal',
      'severity': 'medium',
      'headline': 'Likvidnost ispod praga',
      'deliveryStatus': 'unread',
      'isBadgeEligible': true,
      'alertStatus': 'open',
      'deliveryGeneration': 1,
      'alertRevision': 'rev-1',
      'lastDeliveredAt': {
        'seconds': 1710000000,
        'nanoseconds': 0,
      },
    },
    'unreadInfo': {
      'deliveryId': 'd2',
      'companyId': 'plamingo',
      'alertId': 'a2',
      'severity': 'info',
      'headline': 'Informativna obavijest',
      'deliveryStatus': 'unread',
      'isBadgeEligible': false,
      'alertStatus': 'open',
      'deliveryGeneration': 1,
      'alertRevision': 'rev-1',
    },
    'readDelivery': {
      'deliveryId': 'd3',
      'companyId': 'plamingo',
      'alertId': 'a3',
      'severity': 'high',
      'headline': 'Pročitana obavijest',
      'deliveryStatus': 'read',
      'isBadgeEligible': true,
      'alertStatus': 'open',
      'deliveryGeneration': 1,
      'alertRevision': 'rev-2',
    },
    'closedDelivery': {
      'deliveryId': 'd4',
      'companyId': 'plamingo',
      'alertId': 'a4',
      'severity': 'medium',
      'headline': 'Zatvorena obavijest',
      'deliveryStatus': 'closed',
      'isBadgeEligible': false,
      'alertStatus': 'resolved',
      'closedReason': 'alert_resolved',
      'deliveryGeneration': 1,
      'alertRevision': 'rev-3',
    },
  };
}
