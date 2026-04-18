import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:docya_app/widgets/docya_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'MedicoEnCaminoScreen.dart';
import 'home_screen.dart';

class BuscandoMedicoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacion;
  final String motivo;
  final int? consultaId;
  final String pacienteUuid;
  final String? paymentId;
  final String tipoProfesional;

  const BuscandoMedicoScreen({
    super.key,
    required this.direccion,
    required this.ubicacion,
    required this.motivo,
    this.consultaId,
    required this.pacienteUuid,
    this.paymentId,
    this.tipoProfesional = "medico",
  });

  @override
  State<BuscandoMedicoScreen> createState() => _BuscandoMedicoScreenState();
}

class _BuscandoMedicoScreenState extends State<BuscandoMedicoScreen>
    with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  late AnimationController _animController;
  Timer? _timer;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;

  String estadoConsulta = "pendiente";
  int _remainingSearchSeconds = 60;

  final String apiBase = "https://docya-railway-production.up.railway.app";

  final String uberMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#122932"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#E0F2F1"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#0B1A22"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#155E63"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#18A999"}]},
    {"featureType": "water", "stylers": [{"color": "#0C2F3A"}]},
    {"featureType": "poi", "stylers": [{"visibility": "off"}]},
    {"featureType": "transit", "stylers": [{"visibility": "off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();

    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    _guardarConsultaActiva();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkEstadoConsulta();
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remainingSearchSeconds <= 0) return;
      setState(() => _remainingSearchSeconds--);
    });

    _timeoutTimer = Timer(const Duration(seconds: 60), () async {
      _stopPolling();

      if (widget.consultaId != null) {
        try {
          await http.post(
            Uri.parse(
              "$apiBase/consultas/${widget.consultaId}/cancelar_busqueda",
            ),
            headers: {"Content-Type": "application/json"},
          );
        } catch (e) {
          debugPrint("Error cancelando búsqueda por timeout: $e");
        }
      }

      if (mounted) {
        DocYaSnackbar.show(
          context,
          title: "No encontramos profesional",
          message:
              "Tu dinero fue devuelto automáticamente. Si aparece una opción disponible, podemos comunicarnos por WhatsApp.",
          type: SnackType.warning,
        );
      }

      _volverAlHome();
    });
  }

  String get _professionalLabel =>
      widget.tipoProfesional == "enfermero" ? "enfermero" : "médico";

  String get _professionalPlural =>
      widget.tipoProfesional == "enfermero" ? "enfermeros" : "médicos";

  Future<void> _guardarConsultaActiva() async {
    if (widget.consultaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("consulta_activa_id", widget.consultaId.toString());
  }

  Future<void> _limpiarConsultaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("consulta_activa_id");
  }

  void _stopPolling() {
    _timer?.cancel();
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
  }

  void _volverAlHome() {
    // NO borramos consulta_activa_id aquí: si el admin reasigna la consulta
    // antes de que el paciente vuelva a abrir la app, el HomeScreen y el
    // SplashScreen pueden restaurar la pantalla correcta.
    // La limpieza ocurre en SplashScreen cuando el estado es terminal
    // (finalizada/cancelada) o cuando el HomeScreen lo detecta al resumir.

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          onToggleTheme: () {},
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _cancelarBusquedaManual() async {
    _stopPolling();

    if (widget.consultaId != null) {
      try {
        await http.post(
          Uri.parse(
            "$apiBase/consultas/${widget.consultaId}/cancelar_busqueda",
          ),
          headers: {"Content-Type": "application/json"},
        );
      } catch (e) {
        debugPrint("Error cancelando búsqueda manual: $e");
      }
    }

    if (!mounted) return;

    DocYaSnackbar.show(
      context,
      title: "Búsqueda cancelada",
      message: "Cancelaste la búsqueda del profesional.",
      type: SnackType.warning,
    );

    Future.delayed(const Duration(milliseconds: 500), _volverAlHome);
  }

  Future<void> _checkEstadoConsulta() async {
    if (widget.consultaId == null) return;

    final url = "$apiBase/consultas/${widget.consultaId}";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final nuevoEstado = (data["estado"] ?? "").toString();
      final mpStatus = (data["mp_status"] ?? "").toString();

      if (!mounted) return;

      setState(() => estadoConsulta = nuevoEstado);

      if (nuevoEstado == "cancelada") {
        _stopPolling();

        final message = mpStatus == "cancelled" || mpStatus == "refunded"
            ? "No encontramos un profesional disponible. Tu dinero fue devuelto automáticamente."
            : "No encontramos un profesional disponible en esta ronda.";

        DocYaSnackbar.show(
          context,
          title: "No encontramos profesional",
          message: message,
          type: SnackType.warning,
        );

        Future.delayed(const Duration(milliseconds: 900), _volverAlHome);
        return;
      }

      if (nuevoEstado == "aceptada") {
        _stopPolling();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MedicoEnCaminoScreen(
              direccion: widget.direccion,
              ubicacionPaciente: widget.ubicacion,
              motivo: widget.motivo,
              medicoId: data["medico_id"],
              nombreMedico: data["medico_nombre"] ?? "Profesional asignado",
              matricula: data["medico_matricula"] ?? "N/A",
              consultaId: widget.consultaId!,
              pacienteUuid: widget.pacienteUuid,
              tipo: data["tipo"] ?? widget.tipoProfesional,
            ),
          ),
        );
        return;
      }

      if (nuevoEstado == "rechazada") {
        _stopPolling();
        DocYaSnackbar.show(
          context,
          title: "Consulta finalizada",
          message: "No hubo una aceptación disponible para tu pedido.",
          type: SnackType.warning,
        );
        _volverAlHome();
        return;
      }

      if (nuevoEstado == "sin_profesionales" || nuevoEstado == "sin_medicos") {
        _stopPolling();
        DocYaSnackbar.show(
          context,
          title: "Sin profesionales disponibles",
          message:
              "No encontramos un profesional disponible en este momento. Tu dinero fue devuelto automáticamente.",
          type: SnackType.warning,
        );
        _volverAlHome();
      }
    } catch (e) {
      debugPrint("Error consultando estado: $e");
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async => false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F2027),
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                _mapController.setMapStyle(uberMapStyle);
              },
              initialCameraPosition:
                  CameraPosition(target: widget.ubicacion, zoom: 15),
              markers: {
                Marker(
                  markerId: const MarkerId("user"),
                  position: widget.ubicacion,
                  icon: BitmapDescriptor.defaultMarkerWithHue(170),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
            Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  final size = 120 + (_animController.value * 220);
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF14B8A6)
                          .withOpacity(1 - _animController.value),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset("assets/logoblanco.png", height: 65),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Estamos buscando el $_professionalLabel más cercano a tu ubicación...",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tiempo restante: ${_remainingSearchSeconds}s",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _cancelarBusquedaManual,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Cancelar búsqueda",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
