// ==========================================================
// DOCYA PACIENTE – MAIN FINAL 2025
// iOS + Android 100% Compatible
// Chat + Notificaciones Push + Sonido
// ==========================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';

// Navegación global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();


// ==========================================================
// 🔥 BACKGROUND HANDLER
// ==========================================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📩 PUSH BACKGROUND: ${message.data}");

  if (message.data["tipo"] == "nuevo_mensaje") {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Nuevo mensaje",
      message.data["mensaje"] ?? "",
      NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel_id',
          'Notificaciones DocYa',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alerta'),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        "consulta_id": message.data["consulta_id"],
        "remitente_id": message.data["remitente_id"],
      }),
    );
  }
}


// ==========================================================
// TAP NOTIFICACIÓN LOCAL → abrir chat
// ==========================================================
void _handleLocalNotificationTap(String payload) {
  print("📲 TAP LOCAL NOTIFICATION: $payload");
  final data = jsonDecode(payload);

  navigatorKey.currentState!.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        consultaId: int.parse(data["consulta_id"]),
        remitenteTipo: "paciente",
        remitenteId: data["remitente_id"].toString(),
      ),
    ),
  );
}


// ==========================================================
// NOTIFICACIÓN LOCAL EN FOREGROUND
// ==========================================================
Future<void> mostrarNotificacionLocal(
  String title,
  String body, {
  required int consultaId,
  required String remitenteId,
}) async {
  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel_id',
        'Notificaciones DocYa',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('alerta'),
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: jsonEncode({
      "consulta_id": consultaId,
      "remitente_id": remitenteId,
    }),
  );
}


// ==========================================================
// MAIN
// ==========================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Canal Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
    const AndroidNotificationChannel(
      'default_channel_id',
      'Notificaciones DocYa',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alerta'),
    ),
  );

  // Inicialización de notificaciones locales
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      if (resp.payload != null) {
        _handleLocalNotificationTap(resp.payload!);
      }
    },
  );

  runApp(const DocYaApp());
}


// ==========================================================
// APP
// ==========================================================
class DocYaApp extends StatefulWidget {
  const DocYaApp({super.key});

  @override
  State<DocYaApp> createState() => _DocYaAppState();
}

class _DocYaAppState extends State<DocYaApp> {
  bool darkMode = true;

  @override
  void initState() {
    super.initState();
    _initEverything();
  }

  Future<void> _initEverything() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await _pedirPermisosNotificaciones();
    _setupPushListeners();
    _cargarModo();
    _fixAPNS();
    _checkInitialPush(); // iOS cuando abren la app tocando la noti
  }

  // ==========================================================
  // FIX iOS – si abren la app desde la notificación
  // ==========================================================
  Future<void> _checkInitialPush() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg == null) return;

    print("🍏 NOTIFICACIÓN CON APP CERRADA: ${msg.data}");

    if (msg.data["tipo"] == "nuevo_mensaje") {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            consultaId: int.parse(msg.data["consulta_id"]),
            remitenteTipo: "paciente",
            remitenteId: msg.data["remitente_id"],
          ),
        ),
      );
    }
  }

  // ==========================================================
  // APNS FIX
  // ==========================================================
  Future<void> _fixAPNS() async {
    print("🍏 Esperando APNS…");
    String? apns = await FirebaseMessaging.instance.getAPNSToken();

    int retry = 0;
    while (apns == null && retry < 8) {
      await Future.delayed(const Duration(milliseconds: 500));
      apns = await FirebaseMessaging.instance.getAPNSToken();
      retry++;
    }

    print("🍏 APNS TOKEN: $apns");
    print("🔥 FCM TOKEN: ${await FirebaseMessaging.instance.getToken()}");
  }

  // ==========================================================
  // Permisos
  // ==========================================================
  Future<void> _pedirPermisosNotificaciones() async {
    await Permission.notification.request();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ==========================================================
  // Push listeners
  // ==========================================================
  void _setupPushListeners() {
    // Foreground
    FirebaseMessaging.onMessage.listen((msg) {
      print("📥 FOREGROUND: ${msg.data}");

      if (msg.data["tipo"] == "nuevo_mensaje") {
        mostrarNotificacionLocal(
          "Nuevo mensaje",
          msg.data["mensaje"] ?? "",
          consultaId: int.parse(msg.data["consulta_id"]),
          remitenteId: msg.data["remitente_id"],
        );
      }
    });

    // TAP con app abierta o background
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      print("📲 TAP MESSAGE: ${msg.data}");

      if (msg.data["tipo"] == "nuevo_mensaje") {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              consultaId: int.parse(msg.data["consulta_id"]),
              remitenteTipo: "paciente",
              remitenteId: msg.data["remitente_id"],
            ),
          ),
        );
      }
    });
  }

  // ==========================================================
  // Modo oscuro
  // ==========================================================
  Future<void> _cargarModo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool("darkMode") ?? true;
    });
  }

  // ==========================================================
  // Rutas
  // ==========================================================
  Route<dynamic>? _generarRuta(RouteSettings settings) {
    switch (settings.name) {
      case "/splash":
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case "/login":
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case "/home":
        return MaterialPageRoute(
          builder: (_) => FutureBuilder(
            future: SharedPreferences.getInstance(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final prefs = snap.data!;
              return HomeScreen(
                nombreUsuario: prefs.getString("nombreUsuario") ?? "Usuario",
                userId: prefs.getString("userId") ?? "",
                onToggleTheme: () async {
                  setState(() => darkMode = !darkMode);
                  final p = await SharedPreferences.getInstance();
                  p.setBool("darkMode", darkMode);
                },
              );
            },
          ),
        );

      default:
        return null;
    }
  }

  // ==========================================================
  // UI FINAL
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: Color(0xFF14B8A6)),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFF14B8A6)),
      ),
      initialRoute: "/splash",
      onGenerateRoute: _generarRuta,
    );
  }
}
