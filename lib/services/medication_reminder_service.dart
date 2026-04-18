import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class MedicationReminderService {
  // Usa el plugin que inicializó main.dart — NO crea instancia propia
  static FlutterLocalNotificationsPlugin? _plugin;
  static const Duration _recentDoseGrace = Duration(minutes: 10);
  static const Duration _retryDelay = Duration(seconds: 15);
  static const String _channelId = 'medication_reminders_v2';
  static const String _channelName = 'Recordatorios de medicacion';
  static const String _androidSound = 'medicacion_alerta';
  static const String _iosSound = 'medicacion_alerta.caf';

  /// Debe llamarse desde main.dart DESPUÉS de inicializar el plugin global.
  static void init(FlutterLocalNotificationsPlugin plugin) {
    _plugin = plugin;
  }

  static int _notificationId(int tomaId) => 700000 + tomaId;
  // ID separado para la notificación anticipada (5 min antes)
  static int _advanceNotificationId(int tomaId) => 800000 + tomaId;

  static tz.TZDateTime? _parseSchedule(String fecha, String horario) {
    final dateParts = fecha.split('-');
    final timeParts = horario.split(':');
    if (dateParts.length < 3 || timeParts.length < 2) return null;
    return tz.TZDateTime(
      tz.local,
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  static tz.TZDateTime? _resolveNotificationTime(
    tz.TZDateTime scheduled,
    tz.TZDateTime now,
  ) {
    if (!scheduled.isBefore(now)) return scheduled;
    final elapsed = now.difference(scheduled);
    if (elapsed <= _recentDoseGrace) return now.add(_retryDelay);
    return null;
  }

  static Future<void> syncAgenda(List<Map<String, dynamic>> agenda) async {
    final plugin = _plugin;
    if (plugin == null) {
      // Si por algún motivo no se llamó init(), no hacer nada para no crashear
      return;
    }

    final activeIds = <int>{};
    final now = tz.TZDateTime.now(tz.local);

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Avisos de tomas programadas',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_androidSound),
        enableVibration: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: _iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    for (final item in agenda) {
      final tomaId = item['id'];
      final estado = (item['estado'] ?? 'pendiente').toString();
      final fecha = item['fecha']?.toString();
      final horario = item['horario_programado']?.toString();
      if (tomaId is! int || fecha == null || horario == null) continue;

      final scheduled = _parseSchedule(fecha, horario);
      if (scheduled == null) continue;

      final notifId = _notificationId(tomaId);
      final advanceId = _advanceNotificationId(tomaId);
      activeIds.add(notifId);
      activeIds.add(advanceId);

      if (estado != 'pendiente') {
        await plugin.cancel(notifId);
        await plugin.cancel(advanceId);
        continue;
      }

      final nombre = item['nombre'] ?? 'Medicación';
      final dosis = (item['dosis'] ?? '').toString().trim();
      final bodyPrecise = dosis.isNotEmpty ? '$nombre - $dosis' : nombre;

      // ── Notificación puntual (hora exacta) ─────────────────────────────
      final notifTime = _resolveNotificationTime(scheduled, now);
      if (notifTime != null) {
        await plugin.zonedSchedule(
          notifId,
          '💊 Hora de tu medicación',
          bodyPrecise,
          notifTime,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        await plugin.cancel(notifId);
      }

      // ── Notificación anticipada (5 min antes) ──────────────────────────
      final advanceTime = scheduled.subtract(const Duration(minutes: 5));
      if (advanceTime.isAfter(now)) {
        await plugin.zonedSchedule(
          advanceId,
          '⏰ En 5 minutos: medicación',
          bodyPrecise,
          advanceTime,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        await plugin.cancel(advanceId);
      }
    }

    // Cancelar notificaciones huérfanas
    final pending = await plugin.pendingNotificationRequests();
    for (final request in pending) {
      final id = request.id;
      if ((id >= 700000 && id < 900000) && !activeIds.contains(id)) {
        await plugin.cancel(id);
      }
    }
  }
}
