import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

class LiveActivityService {
  LiveActivityService._();

  static final LiveActivityService instance = LiveActivityService._();

  static const String appGroupId = 'group.com.docya.paciente.liveactivities';
  static const String _activityPrefix = 'consulta-live-';

  final LiveActivities _plugin = LiveActivities();
  bool _initialized = false;
  bool _supported = false;

  Future<void> init() async {
    if (_initialized || !Platform.isIOS) return;

    try {
      await _plugin.init(
        appGroupId: appGroupId,
        urlScheme: 'docya',
        requestAndroidNotificationPermission: false,
      );
      _supported = await _plugin.areActivitiesSupported() &&
          await _plugin.areActivitiesEnabled();
      _initialized = true;
    } catch (e) {
      debugPrint('LiveActivity init error: $e');
    }
  }

  Future<void> syncMedicoEnCamino({
    required int consultaId,
    required String nombreProfesional,
    required String rolProfesional,
    required String estado,
    required String direccion,
    required String motivo,
    required int etaMinutos,
    required double distanciaKm,
  }) async {
    await init();
    if (!_initialized || !_supported) return;

    final activityId = '$_activityPrefix$consultaId';
    final payload = <String, dynamic>{
      'consultaId': consultaId,
      'professionalName': nombreProfesional,
      'professionalRole': rolProfesional,
      'statusText': estado,
      'address': direccion,
      'reason': motivo,
      'etaMinutes': etaMinutos,
      'etaText': etaMinutos <= 1 ? '1 min' : '$etaMinutos min',
      'distanceKm': distanciaKm,
      'distanceText': distanciaKm < 1
          ? '${(distanciaKm * 1000).round()} m'
          : '${distanciaKm.toStringAsFixed(1)} km',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _plugin.createOrUpdateActivity(
        activityId,
        payload,
        staleIn: const Duration(minutes: 15),
      );
    } catch (e) {
      debugPrint('LiveActivity sync error: $e');
    }
  }

  Future<void> endConsulta(int consultaId) async {
    await init();
    if (!_initialized || !_supported) return;

    try {
      await _plugin.endActivity('$_activityPrefix$consultaId');
    } catch (e) {
      debugPrint('LiveActivity end error: $e');
    }
  }

  Future<void> endAll() async {
    await init();
    if (!_initialized || !_supported) return;

    try {
      await _plugin.endAllActivities();
    } catch (e) {
      debugPrint('LiveActivity endAll error: $e');
    }
  }
}
