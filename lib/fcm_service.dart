
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<String>? _tokenRefresh;

  bool _disposed = false;

  Future<void> initialize({
    required void Function(RemoteMessage, String) onData,
    required void Function(String) onStatus,
  }) async {
    if (_disposed || _foreground != null) {
      throw StateError(
        'Use a new service instance for initialization.',
      );
    }

    // Handle a received message or notification tap.
    void receive(String source, RemoteMessage message) {
      if (_disposed) return;

      debugPrint('$source: ${message.messageId}');
      onData(message, source);
    }

    // Report errors from messaging streams.
    void streamError(Object error, StackTrace stack) {
      debugPrint('FCM stream error: $error\n$stack');

      if (!_disposed) {
        onStatus('Messaging stream error: $error');
      }
    }

    // T1: App is open and visible.
    _foreground = FirebaseMessaging.onMessage.listen(
      (message) => receive('onMessage', message),
      onError: streamError,
    );

    // T2: User taps a notification while app is backgrounded.
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => receive('onMessageOpenedApp', message),
      onError: streamError,
    );

    // T3: User taps a notification to launch a terminated app.
    final initialMessage = await messaging.getInitialMessage();

    if (_disposed) return;

    if (initialMessage != null) {
      receive('getInitialMessage', initialMessage);
    }

    // Request notification permission.
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (_disposed) return;

    onStatus(
      'Permission: ${settings.authorizationStatus.name}',
    );

    // Apple platforms require an APNs token.
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final apnsToken = await messaging.getAPNSToken();

      if (_disposed) return;

      if (apnsToken == null) {
        throw StateError(
          'APNs token is not ready. Check signing, '
          'capabilities, and APNs setup, then relaunch.',
        );
      }
    }

    // Observe changes to the FCM registration token.
    _tokenRefresh = messaging.onTokenRefresh.listen(
      (token) {
        if (_disposed) return;

        debugPrint(
          'FCM token refreshed (development only): $token',
        );

        onStatus(
          'Token refreshed. Use the current token '
          'for the next test.',
        );
      },
      onError: streamError,
    );

    // Retrieve the current device token.
    final token = await messaging.getToken();

    if (_disposed) return;

    if (token == null) {
      throw StateError(
        'No FCM token. Check network and platform setup.',
      );
    }

    debugPrint(
      'FCM token (development only): $token',
    );
  }

  // Cancel listeners when the owning widget is removed.
  Future<void> dispose() async {
    _disposed = true;

    await _foreground?.cancel();
    await _opened?.cancel();
    await _tokenRefresh?.cancel();
  }
}
