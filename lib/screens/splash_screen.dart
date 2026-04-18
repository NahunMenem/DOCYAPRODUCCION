import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/force_update_dialog.dart';
import '../globals.dart';
import '../services/live_activity_service.dart';
import 'buscando_medico_screen.dart';
import 'MedicoEnCaminoScreen.dart';
import 'EnfermeroEnCaminoScreen.dart';
import 'consulta_en_curso_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _startupTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  // ======================================================
  // 🔎 CHECK UPDATE (NO SE ROMPE)
  // ======================================================
  Future<void> _checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      String version = info.version.trim();

      // Normalizar "1.0" → "1.0.0"
      final parts = version.split('.');
      if (parts.length == 2) {
        version = "${parts[0]}.${parts[1]}.0";
      }

      final url = "$API_URL/app/check_update?version=$version";
      final r = await http.get(Uri.parse(url)).timeout(_startupTimeout);

      if (r.statusCode != 200) {
        await _goNext();
        return;
      }

      final data = jsonDecode(r.body);

      if (data["force_update"] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ForceUpdateDialog(
            mensaje: data["mensaje"],
            urlAndroid: data["url_android"],
            urlIos: data["url_ios"],
          ),
        );
      } else {
        await _goNext();
      }
    } catch (e) {
      debugPrint("❌ Error check_update: $e");
      await _goNext();
    }
  }

  // ======================================================
  // 🚀 RESTAURAR CONSULTA O LOGIN
  // ======================================================
  Future<void> _goNext() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint("🔎 Splash paciente: iniciando restauracion");

    // 1️⃣ Intentar restaurar desde el ID guardado localmente
    final consultaIdStr = prefs.getString("consulta_activa_id");
    debugPrint("🔎 Splash paciente: consulta_activa_id local=$consultaIdStr");
    if (consultaIdStr != null) {
      final consultaId = int.tryParse(consultaIdStr);
      if (consultaId != null) {
        final navegado = await _intentarNavegar(prefs, consultaId: consultaId);
        debugPrint(
            "🔎 Splash paciente: navegar por id local=$consultaId resultado=$navegado");
        if (navegado) return;
      }
      // ID inválido o consulta no encontrada → limpiar
      await prefs.remove("consulta_activa_id");
    }

    // 2️⃣ Fallback: consultar el backend directamente por UUID del paciente.
    //    Esto cubre el caso de asignación manual donde el ID local quedó
    //    desactualizado (p.ej. el admin asignó una consulta distinta a la
    //    que estaba guardada, o el paciente nunca la guardó).
    final userId = prefs.getString("userId");
    if (userId != null && userId.isNotEmpty) {
      debugPrint(
          "🔎 Splash paciente: consultando backend por consulta_activa userId=$userId");
      try {
        final r = await http
            .get(
              Uri.parse("$API_URL/pacientes/$userId/consulta_activa"),
            )
            .timeout(_startupTimeout);
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          debugPrint("🔎 Splash paciente: respuesta consulta_activa=$data");
          if (data["activa"] == true) {
            final consultaId = data["id"] as int;
            await prefs.setString("consulta_activa_id", consultaId.toString());
            final navegado = await _intentarNavegar(prefs,
                datos: data, consultaId: consultaId);
            debugPrint(
                "🔎 Splash paciente: navegar por backend consultaId=$consultaId resultado=$navegado");
            if (navegado) return;
          }
        }
      } catch (_) {}
    }

    // 👉 Flujo normal: ir al login
    await LiveActivityService.instance.endAll();
    Future.delayed(const Duration(milliseconds: 400), () {
      debugPrint("🧭 Splash paciente: navegando a login");
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/login");
    });
  }

  /// Navega a la pantalla correcta según el estado de la consulta.
  /// Devuelve true si navegó, false si el estado no es recuperable.
  Future<bool> _intentarNavegar(
    SharedPreferences prefs, {
    required int consultaId,
    Map<String, dynamic>? datos,
  }) async {
    try {
      Map<String, dynamic> data;
      if (datos != null) {
        data = datos;
        // El endpoint /consulta_activa no tiene paciente_uuid directamente,
        // lo leemos de prefs
        data.putIfAbsent(
            "paciente_uuid", () => prefs.getString("userId") ?? "");
      } else {
        final r = await http
            .get(Uri.parse("$API_URL/consultas/$consultaId"))
            .timeout(_startupTimeout);
        if (r.statusCode != 200) return false;
        data = jsonDecode(r.body) as Map<String, dynamic>;
      }

      final estado = (data["estado"] ?? "").toString();
      final tipo = (data["tipo"] ?? "medico").toString();
      final pacienteUuid =
          (data["paciente_uuid"] ?? prefs.getString("userId") ?? "").toString();
      debugPrint(
          "🧭 Splash paciente: evaluar consultaId=$consultaId estado=$estado tipo=$tipo");

      if (estado == "pendiente") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BuscandoMedicoScreen(
              direccion: data["direccion"] ?? "",
              ubicacion: LatLng(
                (data["lat"] as num?)?.toDouble() ?? 0,
                (data["lng"] as num?)?.toDouble() ?? 0,
              ),
              motivo: data["motivo"] ?? "",
              consultaId: consultaId,
              pacienteUuid: pacienteUuid,
              paymentId:
                  (data["payment_id"] ?? data["mp_payment_id"])?.toString(),
              tipoProfesional: tipo,
            ),
          ),
        );
        return true;
      }

      if (estado == "aceptada" || estado == "en_camino") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => tipo == "enfermero"
                ? EnfermeroEnCaminoScreen(
                    direccion: data["direccion"] ?? "",
                    ubicacionPaciente: LatLng(
                      (data["lat"] as num?)?.toDouble() ?? 0,
                      (data["lng"] as num?)?.toDouble() ?? 0,
                    ),
                    motivo: data["motivo"] ?? "",
                    enfermeroId: data["medico_id"],
                    nombreEnfermero:
                        data["medico_nombre"] ?? "Profesional asignado",
                    matricula: data["medico_matricula"] ?? "N/A",
                    consultaId: consultaId,
                    pacienteUuid: pacienteUuid,
                  )
                : MedicoEnCaminoScreen(
                    direccion: data["direccion"] ?? "",
                    ubicacionPaciente: LatLng(
                      (data["lat"] as num?)?.toDouble() ?? 0,
                      (data["lng"] as num?)?.toDouble() ?? 0,
                    ),
                    motivo: data["motivo"] ?? "",
                    medicoId: data["medico_id"],
                    nombreMedico:
                        data["medico_nombre"] ?? "Profesional asignado",
                    matricula: data["medico_matricula"] ?? "N/A",
                    consultaId: consultaId,
                    pacienteUuid: pacienteUuid,
                    tipo: tipo,
                  ),
          ),
        );
        return true;
      }

      if (estado == "en_domicilio" || estado == "en_curso") {
        await LiveActivityService.instance.endConsulta(consultaId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultaEnCursoScreen(
              consultaId: consultaId,
              profesionalId: data["medico_id"],
              pacienteUuid: pacienteUuid,
              nombreProfesional:
                  data["medico_nombre"] ?? "Profesional asignado",
              especialidad: data["especialidad"] ?? "",
              matricula: data["medico_matricula"] ?? "N/A",
              motivo: data["motivo"] ?? "",
              direccion: data["direccion"] ?? "",
              horaInicio: DateFormat("HH:mm").format(DateTime.now()),
              tipo: tipo,
            ),
          ),
        );
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ======================================================
  // 🎨 UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
