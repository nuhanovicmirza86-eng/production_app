import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:production_app/modules/auth/register/screens/pending_users_screen.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_screen.dart';
import 'package:production_app/modules/production/ooe/screens/ooe_dashboard_screen.dart';
import 'package:production_app/modules/production/ooe/screens/ooe_shift_summary_screen.dart';
import 'package:production_app/modules/production/production_orders/screens/production_order_details_screen.dart';
import 'package:production_app/modules/quality/screens/quality_hub_screen.dart';

import 'mes_navigation_context_service.dart';

class MesPushNavigation {
  MesPushNavigation._();

  static String _ps(dynamic v) => (v ?? '').toString().trim();

  /// Ista logika za FCM [RemoteMessage], lokalnu notifikaciju (foreground) i bilo koji map data payload.
  static Future<void> handleData(
    Map<String, dynamic> data,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (_ps(data['type']) != 'MES_NOTIFICATION') return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final cd = await MesNavigationContextService.loadForCurrentUser();
    if (cd == null) return;

    if (!nav.mounted) return;

    final route = _ps(data['deepLinkRoute']);
    final entityType = _ps(data['entityType']);
    final entityId = _ps(data['entityId']);
    final orderIdFromData = _ps(data['productionOrderId']);
    final summaryIdFromData = _ps(data['summaryId']);

    switch (route) {
      case 'production_order':
        final orderId = (entityType == 'production_order' && entityId.isNotEmpty)
            ? entityId
            : orderIdFromData;
        if (orderId.isNotEmpty) {
          await nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ProductionOrderDetailsScreen(
                companyData: cd,
                productionOrderId: orderId,
              ),
            ),
          );
        }
        break;
      case 'quality_hub':
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => QualityHubScreen(companyData: cd),
          ),
        );
        break;
      case 'ooe_dashboard':
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OoeDashboardScreen(companyData: cd),
          ),
        );
        break;
      case 'ooe_shift_summary':
        final sid = summaryIdFromData.isNotEmpty
            ? summaryIdFromData
            : _ps(data['entityId']);
        if (sid.isNotEmpty) {
          await nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => OoeShiftSummaryScreen(
                companyData: cd,
                initialSummaryDocId: sid,
              ),
            ),
          );
        }
        break;
      case 'pending_users':
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const PendingUsersScreen(),
          ),
        );
        break;
      case 'mes_inbox':
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MesInboxScreen(companyData: cd),
          ),
        );
        break;
      default:
        await nav.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MesInboxScreen(companyData: cd),
          ),
        );
    }
  }

  static Future<void> handleMessage(
    RemoteMessage msg,
    GlobalKey<NavigatorState> navigatorKey,
  ) =>
      handleData(msg.data, navigatorKey);
}
