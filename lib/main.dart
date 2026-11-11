import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'fcm_service.dart';

// Background messages are handled outside the widget tree.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('onBackgroundMessage: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cloud Courier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FCMService _fcmService = FCMService();

  static const Map<String, String> _assets = {
    'default': 'assets/images/default.png',
    'promo': 'assets/images/promo.png',
  };

  String _statusText = 'Waiting for a cloud message';
  String _imagePath = 'assets/images/default.png';
  String _feedback = 'Initializing messaging...';
  String _lastHandler = 'None yet';
  String _lastMessageId = 'None yet';

  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeMessaging());
  }

  void _report(String text) {
    debugPrint(text);

    if (mounted) {
      setState(() {
        _feedback = text;
      });
    }
  }

  Future<void> _initializeMessaging() async {
    try {
      await _fcmService.initialize(onData: _handleMessage, onStatus: _report);
    } on FirebaseException catch (error, stack) {
      debugPrint('Firebase error: $error\n$stack');

      _report('Messaging error (${error.code}): ${error.message}');
    } on StateError catch (error, stack) {
      debugPrint('Messaging setup error: $error\n$stack');

      _report(error.message.toString());
    }
  }

  void _handleMessage(RemoteMessage message, String source) {
    if (!mounted) return;

    // Record the message even if its payload is invalid.
    setState(() {
      _lastHandler = source;
      _lastMessageId = message.messageId ?? '(no ID)';
      _messageCount += 1;
    });

    // Only allow known asset names.
    final path = _assets[message.data['asset']];

    if (message.data['action'] != 'update_ui' || path == null) {
      _report(
        'Rejected payload: use action=update_ui and '
        'asset=default or asset=promo. '
        'Previous content preserved.',
      );
      return;
    }

    // Apply valid payload data to the visible UI.
    setState(() {
      _statusText = message.notification?.title ?? 'Payload received';

      _imagePath = path;

      _feedback = 'Applied payload ${message.messageId ?? "(no ID)"}';
    });
  }

  @override
  void dispose() {
    unawaited(
      _fcmService.dispose().catchError((Object error, StackTrace stack) {
        debugPrint('FCM cleanup error: $error\n$stack');
      }),
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Courier'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _statusText,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          Image.asset(
            _imagePath,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) {
              debugPrint('Asset load error: $error');

              return Text(
                'Cannot load $_imagePath. '
                'Check your assets folder.',
              );
            },
          ),

          const SizedBox(height: 24),

          const Divider(),

          Text('Last handler: $_lastHandler'),

          const SizedBox(height: 8),

          Text('Messages handled this launch: $_messageCount'),

          const SizedBox(height: 8),

          Text('Last message ID: $_lastMessageId'),

          const Divider(),

          const SizedBox(height: 12),

          Text(
            _feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
