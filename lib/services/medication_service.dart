import 'dart:convert';

import 'package:http/http.dart' as http;

import '../globals.dart';

class MedicationService {
  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$API_URL$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getTodayDoses(
    String pacienteUuid,
  ) async {
    final response =
        await http.get(_uri('/pastillero/tomas/hoy/$pacienteUuid'));
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las tomas de hoy');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ((data['tomas'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getAgenda(
    String pacienteUuid, {
    int dias = 7,
  }) async {
    final response = await http.get(
      _uri('/pastillero/agenda/$pacienteUuid', {'dias': dias}),
    );
    if (response.statusCode == 404) {
      return [];
    }
    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar la agenda de medicación');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ((data['agenda'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMedicaciones(
    String pacienteUuid,
  ) async {
    final response =
        await http.get(_uri('/pastillero/medicaciones/$pacienteUuid'));
    if (response.statusCode != 200) {
      throw Exception('No se pudieron cargar las medicaciones');
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ((data['medicaciones'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> getHistorial(
    String pacienteUuid, {
    int days = 30,
  }) async {
    final response = await http.get(
      _uri('/pastillero/historial/$pacienteUuid', {'days': days}),
    );
    if (response.statusCode == 404) {
      return {
        'ok': true,
        'resumen': {
          'total': 0,
          'tomadas': 0,
          'omitidas': 0,
          'pendientes': 0,
          'adherencia_pct': 0,
        },
        'historial': const [],
      };
    }
    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar el historial');
    }
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  static Future<void> createMedication({
    required String pacienteUuid,
    required String nombre,
    required String dosis,
    required List<String> horarios,
    String? frecuencia,
    String? observaciones,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final response = await http.post(
      _uri('/pastillero/medicacion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paciente_uuid': pacienteUuid,
        'nombre': nombre,
        'dosis': dosis,
        'frecuencia': frecuencia,
        'horarios': horarios,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'observaciones': observaciones,
      }),
    );
    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes).trim();
      throw Exception(body.isEmpty ? 'No se pudo guardar la medicación' : body);
    }
  }

  static Future<void> updateDose(int tomaId, String estado) async {
    final response = await http.post(
      _uri('/pastillero/toma/actualizar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'toma_id': tomaId,
        'estado': estado,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar la toma');
    }
  }

  static Future<void> editMedication({
    required int medicacionId,
    required String pacienteUuid,
    required String nombre,
    required String dosis,
    required List<String> horarios,
    String? frecuencia,
    String? observaciones,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final response = await http.put(
      _uri('/pastillero/medicacion/$medicacionId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'paciente_uuid': pacienteUuid,
        'nombre': nombre,
        'dosis': dosis,
        'frecuencia': frecuencia,
        'horarios': horarios,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'observaciones': observaciones,
      }),
    );
    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes).trim();
      throw Exception(body.isEmpty ? 'No se pudo editar la medicación' : body);
    }
  }

  static Future<void> deleteMedication(int medicacionId) async {
    final response =
        await http.delete(_uri('/pastillero/medicacion/$medicacionId'));
    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes).trim();
      throw Exception(
          body.isEmpty ? 'No se pudo eliminar la medicación' : body);
    }
  }
}
