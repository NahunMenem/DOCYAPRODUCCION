// ==========================================================
// DOCYA PACIENTE – MAIN FINAL 2025
// iOS + Android 100% Compatible
// Chat + Push + Sonido
// ==========================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// 🔥 TIMEZONE
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'services/live_activity_service.dart';
import 'services/medication_reminder_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/buscando_medico_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/consulta_en_curso_screen.dart';
import 'screens/EnfermeroEnCaminoScreen.dart';
import 'screens/MedicoEnCaminoScreen.dart';

// ==========================================================
// NAVIGATOR GLOBAL
// ==========================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ==========================================================
// LOCAL NOTIFICATIONS
// ==========================================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const String kMedicationReminderChannelId = 'medication_reminders_v2';
const String kMedicationReminderChannelName = 'Recordatorios de medicacion';
const String kMedicationReminderAndroidSound = 'medicacion_alerta';
const String kMedicationReminderIosSound = 'medicacion_alerta.caf';

// ==========================================================
// 🔥 BACKGROUND HANDLER (OBLIGATORIO iOS)
// ==========================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();

  // Initialize plugin in this background isolate and ensure channels exist
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'default_channel_id',
      'Notificaciones DocYa',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        kMedicationReminderAndroidSound,
      ),
    ),
  );
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      kMedicationReminderChannelId,
      kMedicationReminderChannelName,
      description: 'Avisos programados del pastillero',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alerta'),
    ),
  );

  if (message.data["tipo"] == "consulta_asignada") {
    final consultaId = message.data["consulta_id"]?.toString();
    if (consultaId != null && consultaId.isNotEmpty) {
      await prefs.setString("consulta_activa_id", consultaId);
    }
    return;
  }

  if (message.data["tipo"] == "nuevo_mensaje") {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Nuevo mensaje",
      message.data["mensaje"] ?? "",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel_id',
          'Notificaciones DocYa',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(
            kMedicationReminderAndroidSound,
          ),
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
    return;
  }

  if (message.data["tipo"] == "medication_reminder") {
    final body = [
      message.data["nombre"] ?? "Medicacion",
      message.data["dosis"] ?? "",
      if ((message.data["horario"] ?? "").toString().isNotEmpty)
        '(${message.data["horario"]})',
    ].where((item) => item.toString().trim().isNotEmpty).join(' ');

    await flutterLocalNotificationsPlugin.show(
      int.tryParse(message.data["toma_id"]?.toString() ?? '') ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "Recordatorio de medicacion",
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kMedicationReminderChannelId,
          kMedicationReminderChannelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('alerta'),
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: kMedicationReminderIosSound,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: jsonEncode({
        "tipo": "medication_reminder",
        "toma_id": message.data["toma_id"],
      }),
    );
  }
}

// ==========================================================
// TAP NOTIFICACIÓN LOCAL → ABRIR CHAT
// ==========================================================
Future<void> _openPatientChatFromPayload(Map<String, dynamic> data) async {
  final consultaIdRaw = data["consulta_id"]?.toString();
  if (consultaIdRaw == null || consultaIdRaw.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString("userId");
  if (userId == null || userId.isEmpty) return;

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        consultaId: int.tryParse(consultaIdRaw),
        remitenteTipo: "paciente",
        remitenteId: userId,
      ),
    ),
  );
}

Future<void> _handleLocalNotificationTap(String payload) async {
  final data = jsonDecode(payload) as Map<String, dynamic>;
  if (data["tipo"]?.toString() == "medication_reminder") {
    navigatorKey.currentState?.pushNamed("/home");
    return;
  }
  if (data["tipo"]?.toString() == "consulta_asignada") {
    await _openConsultaFromPayload(data);
    return;
  }
  await _openPatientChatFromPayload(data);
}

Future<void> _openConsultaFromPayload(Map<String, dynamic> data) async {
  final consultaIdRaw = data["consulta_id"]?.toString();
  final consultaId = int.tryParse(consultaIdRaw ?? "");
  if (consultaId == null) return;
  debugPrint(
      "📩 Paciente _openConsultaFromPayload consultaId=$consultaId data=$data");

  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString("userId");
  if (userId == null || userId.isEmpty) return;
  await prefs.setString("consulta_activa_id", consultaId.toString());
  debugPrint("💾 Paciente payload: consulta_activa_id guardado=$consultaId");

  try {
    http.Response? resp;
    for (var attempt = 0; attempt < 4; attempt++) {
      final currentResp = await http.get(
        Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/$consultaId",
        ),
      );
      if (currentResp.statusCode == 200) {
        resp = currentResp;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 450));
    }
    if (resp == null) return;

    final consulta = jsonDecode(resp.body) as Map<String, dynamic>;
    final estado = (consulta["estado"] ?? "").toString();
    final tipo = (consulta["tipo"] ?? "medico").toString();
    final direccion = (consulta["direccion"] ?? "").toString();
    final motivo = (consulta["motivo"] ?? "").toString();
    final pacienteUuid =
        (consulta["paciente_uuid"] ?? userId).toString().trim().isNotEmpty
            ? (consulta["paciente_uuid"] ?? userId).toString()
            : userId;
    final lat = (consulta["lat"] as num?)?.toDouble() ?? 0;
    final lng = (consulta["lng"] as num?)?.toDouble() ?? 0;
    final medicoId = (consulta["medico_id"] as num?)?.toInt() ?? 0;
    final medicoNombre =
        (consulta["medico_nombre"] ?? "Profesional asignado").toString();
    final matricula = (consulta["medico_matricula"] ?? "N/A").toString();

    await prefs.setString("consulta_activa_id", consultaId.toString());
    debugPrint(
        "🧭 Paciente payload: consultaId=$consultaId estado=$estado tipo=$tipo");

    Route<dynamic>? route;
    if (estado == "pendiente") {
      route = MaterialPageRoute(
        builder: (_) => BuscandoMedicoScreen(
          direccion: direccion,
          ubicacion: LatLng(lat, lng),
          motivo: motivo,
          consultaId: consultaId,
          pacienteUuid: pacienteUuid,
          paymentId:
              (consulta["payment_id"] ?? consulta["mp_payment_id"])?.toString(),
          tipoProfesional: tipo,
        ),
      );
    } else if (estado == "aceptada" || estado == "en_camino") {
      route = MaterialPageRoute(
        builder: (_) => tipo == "enfermero"
            ? EnfermeroEnCaminoScreen(
                direccion: direccion,
                ubicacionPaciente: LatLng(lat, lng),
                motivo: motivo,
                enfermeroId: medicoId,
                nombreEnfermero: medicoNombre,
                matricula: matricula,
                consultaId: consultaId,
                pacienteUuid: pacienteUuid,
              )
            : MedicoEnCaminoScreen(
                direccion: direccion,
                ubicacionPaciente: LatLng(lat, lng),
                motivo: motivo,
                medicoId: medicoId,
                nombreMedico: medicoNombre,
                matricula: matricula,
                consultaId: consultaId,
                pacienteUuid: pacienteUuid,
                tipo: tipo,
              ),
      );
    } else if (estado == "en_domicilio" || estado == "en_curso") {
      route = MaterialPageRoute(
        builder: (_) => ConsultaEnCursoScreen(
          consultaId: consultaId,
          profesionalId: medicoId,
          pacienteUuid: pacienteUuid,
          nombreProfesional: medicoNombre,
          especialidad: (consulta["especialidad"] ?? "").toString(),
          matricula: matricula,
          motivo: motivo,
          direccion: direccion,
          horaInicio: DateFormat("HH:mm").format(DateTime.now()),
          tipo: tipo,
        ),
      );
    }

    if (route == null) return;

    navigatorKey.currentState?.pushAndRemoveUntil(route, (route) => false);
  } catch (_) {}
}

// ==========================================================
// MAIN
// ==========================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }
  }

  // 🔥 TIMEZONE INIT (ARGENTINA READY)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Argentina/Buenos_Aires'));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  // ANDROID CHANNELS – delete first to force sound update if previously cached without it
  final _androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await _androidPlugin?.deleteNotificationChannel('default_channel_id');
  await _androidPlugin?.deleteNotificationChannel(kMedicationReminderChannelId);
  await _androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'default_channel_id',
      'Notificaciones DocYa',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        kMedicationReminderAndroidSound,
      ),
    ),
  );
  await _androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      kMedicationReminderChannelId,
      kMedicationReminderChannelName,
      description: 'Avisos programados del pastillero',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alerta'),
    ),
  );

  // LOCAL NOTIFICATIONS INIT
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

  // Compartir el plugin ya inicializado con el servicio de recordatorios
  MedicationReminderService.init(flutterLocalNotificationsPlugin);

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
    await _pedirPermisosNotificaciones();
    if (Platform.isIOS || Platform.isMacOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    await LiveActivityService.instance.init();
    _setupPushListeners();
    _cargarModo();
    _checkInitialPush();
    _listenTokenRefresh();
  }

  void _listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("userId");
      if (userId == null || userId.isEmpty || newToken.isEmpty) return;
      try {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/users/$userId/fcm_token"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"fcm_token": newToken}),
        );
      } catch (_) {}
    });
  }

  Future<void> _checkInitialPush() async {
    final msg = await FirebaseMessaging.instance.getInitialMessage();
    if (msg == null) return;

    if (msg.data["tipo"] == "consulta_asignada") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openConsultaFromPayload(msg.data);
      });
      return;
    }

    if (msg.data["tipo"] == "nuevo_mensaje") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPatientChatFromPayload(msg.data);
      });
      return;
    }

    if (msg.data["tipo"] == "medication_reminder") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed("/home");
      });
    }
  }

  Future<void> _pedirPermisosNotificaciones() async {
    await Permission.notification.request();

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _setupPushListeners() {
    FirebaseMessaging.onMessage.listen((msg) async {
      if (msg.data["tipo"] == "consulta_asignada") {
        await _openConsultaFromPayload(msg.data);
        return;
      }

      if (msg.data["tipo"] == "nuevo_mensaje") {
        await flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          "Nuevo mensaje",
          msg.data["mensaje"] ?? "",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel_id',
              'Notificaciones DocYa',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(
                kMedicationReminderAndroidSound,
              ),
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode({
            "consulta_id": msg.data["consulta_id"],
            "remitente_id": msg.data["remitente_id"],
          }),
        );
        return;
      }

      if (msg.data["tipo"] == "medication_reminder") {
        final body = [
          msg.data["nombre"] ?? "Medicacion",
          msg.data["dosis"] ?? "",
          if ((msg.data["horario"] ?? "").toString().isNotEmpty)
            '(${msg.data["horario"]})',
        ].where((item) => item.toString().trim().isNotEmpty).join(' ');

        await flutterLocalNotificationsPlugin.show(
          int.tryParse(msg.data["toma_id"]?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch ~/ 1000,
          "Recordatorio de medicacion",
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              kMedicationReminderChannelId,
              kMedicationReminderChannelName,
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
              sound: kMedicationReminderIosSound,
            ),
          ),
          payload: jsonEncode({
            "tipo": "medication_reminder",
            "toma_id": msg.data["toma_id"],
          }),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data["tipo"] == "consulta_asignada") {
        _openConsultaFromPayload(msg.data);
        return;
      }

      if (msg.data["tipo"] == "nuevo_mensaje") {
        _openPatientChatFromPayload(msg.data);
        return;
      }

      if (msg.data["tipo"] == "medication_reminder") {
        navigatorKey.currentState?.pushNamed("/home");
      }
    });
  }

  Future<void> _cargarModo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool("darkMode") ?? true;
    });
  }

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
      case "/complete-profile":
        return MaterialPageRoute(
          builder: (_) => const CompleteProfileScreen(),
        );
      default:
        return null;
    }
  }

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
