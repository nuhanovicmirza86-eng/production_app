import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web Push javni ključ (Firebase → Cloud Messaging → Web configuration).
/// Prazno: SDK koristi certifikat iz projekta. Override: `--dart-define=OPERONIX_WEB_VAPID_KEY=...`
const String kOperonixWebPushVapidKey = String.fromEnvironment(
  'OPERONIX_WEB_VAPID_KEY',
);

/// Isti backend callable kao Maintenance (`registerFcmToken`) — jedan `users` dokument.
class FcmTokenService {
  FcmTokenService._();

  static final FcmTokenService instance = FcmTokenService._();

  StreamSubscription<String>? _tokenRefreshSub;

  bool _initialized = false;
  bool _syncInFlight = false;

  String? _lastSyncedToken;
  String? _lastSyncedUid;

  String? _pendingForcedToken;
  String? _pendingUid;

  bool get _isSupportedPlatform {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  void reset() {
    _lastSyncedToken = null;
    _lastSyncedUid = null;
    _pendingForcedToken = null;
    _pendingUid = null;
    _syncInFlight = false;
    debugPrint('FCM Service state reset (production)');
  }

  Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    if (_initialized) return;

    _initialized = true;

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (e) {
      debugPrint('FCM initialize setAutoInitEnabled error: $e');
    }

    if (kIsWeb) {
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        debugPrint('FCM web requestPermission error: $e');
      }
    }

    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final trimmedToken = token.trim();
      if (trimmedToken.isEmpty) return;

      await syncForUser(user, forcedToken: trimmedToken);
    });
  }

  Future<void> syncCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await syncForUser(user);
  }

  Future<void> syncForUser(User user, {String? forcedToken}) async {
    if (!_isSupportedPlatform) return;

    await initialize();

    final requestedForcedToken = forcedToken?.trim();
    final requestedUid = user.uid;

    if (_syncInFlight) {
      _pendingUid = requestedUid;

      if (requestedForcedToken != null && requestedForcedToken.isNotEmpty) {
        _pendingForcedToken = requestedForcedToken;
      }

      debugPrint('FCM sync queued: already in flight | uid=$requestedUid');
      return;
    }

    _syncInFlight = true;

    try {
      User currentUser = user;
      String? currentForcedToken = requestedForcedToken;

      while (true) {
        if (FirebaseAuth.instance.currentUser?.uid != currentUser.uid) {
          debugPrint(
            'FCM sync aborted: auth user changed before sync | uid=${currentUser.uid}',
          );
          break;
        }

        final token = (currentForcedToken ?? await _getTokenWithRetry()).trim();
        if (token.isEmpty) {
          debugPrint('FCM sync skipped: empty token | uid=${currentUser.uid}');
        } else if (_lastSyncedUid == currentUser.uid &&
            _lastSyncedToken == token) {
          debugPrint(
            'FCM sync skipped: token already synced | uid=${currentUser.uid}',
          );
        } else {
          debugPrint('FCM sync start | uid=${currentUser.uid}');

          final result =
              await FirebaseFunctions.instanceFor(
                region: 'europe-west1',
              ).httpsCallable('registerFcmToken').call({
                'token': token,
                'platform': _platformName(),
              });

          if (FirebaseAuth.instance.currentUser?.uid == currentUser.uid) {
            _lastSyncedUid = currentUser.uid;
            _lastSyncedToken = token;
            debugPrint('FCM sync OK | ${result.data}');
          } else {
            debugPrint(
              'FCM sync finished but auth user changed | uid=${currentUser.uid}',
            );
          }
        }

        final queuedUid = _pendingUid;
        final queuedForcedToken = _pendingForcedToken;

        _pendingUid = null;
        _pendingForcedToken = null;

        if (queuedUid == null) {
          break;
        }

        final latestUser = FirebaseAuth.instance.currentUser;
        if (latestUser == null || latestUser.uid != queuedUid) {
          debugPrint(
            'FCM queued sync dropped: queued user is no longer current | uid=$queuedUid',
          );
          break;
        }

        currentUser = latestUser;
        currentForcedToken = queuedForcedToken?.trim();
      }
    } catch (e, st) {
      debugPrint('FCM sync ERROR: $e');
      debugPrint('$st');
    } finally {
      _syncInFlight = false;
    }
  }

  Future<String> _getTokenWithRetry() async {
    for (int i = 0; i < 6; i++) {
      try {
        final token = (await FirebaseMessaging.instance.getToken(
                  vapidKey: kIsWeb
                      ? (kOperonixWebPushVapidKey.isEmpty
                          ? null
                          : kOperonixWebPushVapidKey)
                      : null,
                ) ??
                '')
            .trim();
        if (token.isNotEmpty) return token;
      } catch (e) {
        debugPrint('FCM getToken try ${i + 1} ERROR: $e');
      }

      if (i < 5) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return '';
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _initialized = false;
  }
}
