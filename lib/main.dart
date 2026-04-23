import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';
import 'package:production_app/core/theme/operonix_production_brand.dart';
import 'package:production_app/modules/auth/session/screens/auth_wrapper.dart';
import 'package:production_app/services/fcm_token_service.dart';

bool get _isDesktopNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

bool get _pushSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

final FlutterLocalNotificationsPlugin _prodLocalNotifs =
    FlutterLocalNotificationsPlugin();

const String _kProdChannelId = 'production_high';
const String _kProdChannelName = 'Operonix Production';
const String _kProdChannelDesc =
    'Obavijesti (npr. javni pozivi / Funding Watcher)';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

String _ps(dynamic v) => (v ?? '').toString().trim();

Future<void> _openFundingCallUrl(String url) async {
  final u = Uri.tryParse(url);
  if (u == null) return;
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

void _handleProductionPushNavigation(RemoteMessage msg) {
  final data = msg.data;
  if (_ps(data['type']) != 'FUNDING_CALL') return;
  final url = _ps(data['url']);
  if (url.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _openFundingCallUrl(url);
  });
}

Future<void> _initProductionLocalNotifications() async {
  if (!_pushSupported) return;

  await _prodLocalNotifs.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (resp) {
      final payload = _ps(resp.payload);
      if (payload.startsWith('external:')) {
        final raw = payload.substring('external:'.length);
        final url = Uri.decodeComponent(raw);
        if (url.isNotEmpty) {
          _openFundingCallUrl(url);
        }
      }
    },
  );

  if (Platform.isIOS) {
    await _prodLocalNotifs
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  const androidChannel = AndroidNotificationChannel(
    _kProdChannelId,
    _kProdChannelName,
    description: _kProdChannelDesc,
    importance: Importance.max,
  );

  await _prodLocalNotifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);
}

Future<void> _showProductionForegroundNotification(RemoteMessage msg) async {
  if (!_pushSupported) return;

  final n = msg.notification;
  final title = _ps(n?.title).isNotEmpty ? _ps(n?.title) : 'Nova obavijest';
  final body = _ps(n?.body);
  final data = msg.data;

  String payload = '';
  if (_ps(data['type']) == 'FUNDING_CALL') {
    final url = _ps(data['url']);
    if (url.isNotEmpty) {
      payload = 'external:${Uri.encodeComponent(url)}';
    }
  }

  const androidDetails = AndroidNotificationDetails(
    _kProdChannelId,
    _kProdChannelName,
    channelDescription: _kProdChannelDesc,
    importance: Importance.max,
    priority: Priority.high,
  );

  const darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const details = NotificationDetails(
    android: androidDetails,
    iOS: darwinDetails,
    macOS: darwinDetails,
  );

  final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

  await _prodLocalNotifs.show(
    id: notifId,
    title: title,
    body: body,
    notificationDetails: details,
    payload: payload.isEmpty ? null : payload,
  );
}

Future<void> _initProductionPushStack() async {
  if (!_pushSupported) return;

  try {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
  } catch (e) {
    debugPrint('Production FCM setAutoInitEnabled: $e');
  }

  if (Platform.isIOS) {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await _initProductionLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await _showProductionForegroundNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleProductionPushNavigation);

  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    _handleProductionPushNavigation(initial);
  }

  await FcmTokenService.instance.initialize();
  await FcmTokenService.instance.syncCurrentUser();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  if (_isDesktopNative) {
    await windowManager.ensureInitialized();
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await _initProductionPushStack();

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
      /// HR kalendari u dijalozima (npr. datum); prikaz punog datuma u tekstu ide preko [BaFormattedDate].
      locale: const Locale('hr', 'BA'),
      supportedLocales: const [
        Locale('hr', 'BA'),
        Locale('bs', 'BA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
