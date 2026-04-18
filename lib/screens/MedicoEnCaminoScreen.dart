import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/live_activity_service.dart';
import '../widgets/docya_snackbar.dart';
import 'chat_screen.dart';
import 'consulta_en_curso_screen.dart';

class MedicoEnCaminoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacionPaciente;
  final String motivo;
  final int medicoId;
  final String nombreMedico;
  final String matricula;
  final int? consultaId;
  final String pacienteUuid;
  final String tipo;

  const MedicoEnCaminoScreen({
    super.key,
    required this.direccion,
    required this.ubicacionPaciente,
    required this.motivo,
    required this.medicoId,
    required this.nombreMedico,
    required this.matricula,
    required this.pacienteUuid,
    this.consultaId,
    required this.tipo,
  });

  @override
  State<MedicoEnCaminoScreen> createState() => _MedicoEnCaminoScreenState();
}

class _MedicoEnCaminoScreenState extends State<MedicoEnCaminoScreen> {
  GoogleMapController? _mapController;
  Timer? _timer;
  BitmapDescriptor? _pacienteMarkerIcon;
  BitmapDescriptor? _profesionalMarkerIcon;

  int etaMinutos = 0;
  double distanciaKm = 0.0;
  double distanciaInicial = 0.0;
  double distanciaActual = 0.0;
  double progreso = 0.0;

  double? _ultimaDistanciaBackend;
  LatLng? _ubicacionMedico;
  DateTime? _ultimoRefresh;
  String? _fotoProfesional;
  bool _mapReady = false;

  String mensaje = "Profesional en camino";
  static const double _distanciaMinimaConfiableMetros = 15;

  final String mapStyle = '''
  [
    {"elementType": "geometry","stylers":[{"color":"#122932"}]},
    {"elementType": "labels.text.fill","stylers":[{"color":"#E0F2F1"}]},
    {"elementType": "labels.text.stroke","stylers":[{"color":"#0B1A22"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#155E63"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#18A999"}]},
    {"featureType":"water","stylers":[{"color":"#0C2F3A"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _guardarConsultaActiva();
    _prepararMarkers();
    _cargarDatos();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cargarDatos();
      _checkEstadoConsulta();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _guardarConsultaActiva() async {
    if (widget.consultaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("consulta_activa_id", widget.consultaId.toString());
  }

  Future<void> _prepararMarkers() async {
    final paciente = await _buildDotMarker(
      fillColor: const Color(0xFFB5FFF8),
      borderColor: const Color(0xFF25D7C8),
      centerColor: const Color(0xFF25D7C8),
      markerSize: 88,
      haloRadius: 0,
    );
    final profesional = await _buildDotMarker(
      fillColor: const Color(0xFF2DD4BF),
      borderColor: Colors.white,
      centerColor: const Color(0xFF06323A),
      markerSize: 116,
      haloRadius: 36,
    );

    if (!mounted) return;
    setState(() {
      _pacienteMarkerIcon = paciente;
      _profesionalMarkerIcon = profesional;
    });
  }

  Future<BitmapDescriptor> _buildDotMarker({
    required Color fillColor,
    required Color borderColor,
    required Color centerColor,
    required double markerSize,
    required double haloRadius,
  }) async {
    final double size = markerSize;
    final double center = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    final fillPaint = Paint()..color = fillColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final centerPaint = Paint()..color = centerColor;
    final haloPaint = Paint()
      ..color = fillColor.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    if (haloRadius > 0) {
      canvas.drawCircle(Offset(center, center), haloRadius, haloPaint);
    }
    canvas.drawCircle(Offset(center + 1, center + 4), size * 0.24, shadowPaint);
    canvas.drawCircle(Offset(center, center), size * 0.22, fillPaint);
    canvas.drawCircle(Offset(center, center), size * 0.22, borderPaint);
    canvas.drawCircle(Offset(center, center), size * 0.075, centerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: math.max(
          ui.PlatformDispatcher.instance.views.first.devicePixelRatio, 2),
    );
  }

  Future<void> _cargarDatos() async {
    if (widget.consultaId == null) return;

    const base = "https://docya-railway-production.up.railway.app";

    try {
      final resp =
          await http.get(Uri.parse("$base/consultas/${widget.consultaId}"));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      final etaBackend =
          int.tryParse("${data["tiempo_estimado_min"] ?? 0}") ?? 0;
      final distanciaKmBackend =
          double.tryParse("${data["distancia_km"] ?? 0}") ?? 0;
      final medicoLat = (data["medico_lat"] as num?)?.toDouble();
      final medicoLng = (data["medico_lng"] as num?)?.toDouble();
      final fotoProfesional =
          (data["medico_foto_perfil"] ?? "").toString().trim();

      final ubicacionMedico = (medicoLat != null && medicoLng != null)
          ? LatLng(medicoLat, medicoLng)
          : null;
      final distanciaDirectaMetros = ubicacionMedico == null
          ? null
          : _distanciaEntrePuntosMetros(
              ubicacionMedico,
              widget.ubicacionPaciente,
            );

      double metros = distanciaKmBackend > 0
          ? distanciaKmBackend * 1000
          : (distanciaDirectaMetros ?? 0);
      final lecturaInconsistente = distanciaDirectaMetros != null &&
          distanciaDirectaMetros <= _distanciaMinimaConfiableMetros &&
          etaBackend > 1;

      if (lecturaInconsistente && distanciaActual > 30) {
        metros = distanciaActual;
      }

      if (_ultimaDistanciaBackend != null &&
          metros > _ultimaDistanciaBackend! + 50) {
        metros = _ultimaDistanciaBackend!;
      }

      _ultimaDistanciaBackend = metros;
      final etaCalculado = _calcularEtaDesdeMetros(metros);
      final etaFinal = lecturaInconsistente
          ? etaCalculado
          : (etaBackend > 0 ? etaBackend : etaCalculado);

      if (!mounted) return;

      setState(() {
        etaMinutos = etaFinal;

        if (distanciaInicial == 0 && metros > 0) {
          distanciaInicial = metros;
        }

        distanciaActual = metros;
        distanciaKm = metros / 1000;
        _ubicacionMedico = ubicacionMedico;
        _ultimoRefresh = DateTime.now();
        _fotoProfesional = fotoProfesional.isEmpty ? null : fotoProfesional;

        if (distanciaInicial > 0) {
          progreso = 1 - (metros / distanciaInicial);
          progreso = progreso.clamp(0.0, 1.0);
        }

        if (metros > 1000) {
          mensaje = "El profesional está en camino";
        } else if (metros > 500) {
          mensaje = "El profesional está cerca";
        } else if (metros > 200) {
          mensaje = "Preparáte para recibirlo";
        } else {
          mensaje = "El profesional está llegando";
        }
      });

      await LiveActivityService.instance.syncMedicoEnCamino(
        consultaId: widget.consultaId!,
        nombreProfesional: widget.nombreMedico,
        rolProfesional: widget.tipo == "enfermero" ? "Enfermero/a" : "Médico/a",
        estado: mensaje,
        direccion: widget.direccion,
        motivo: widget.motivo,
        etaMinutos: etaMinutos,
        distanciaKm: distanciaKm,
      );

      _ajustarMapa();
    } catch (e) {
      debugPrint("Error cargando datos de consulta: $e");
    }
  }

  Future<void> _checkEstadoConsulta() async {
    if (widget.consultaId == null) return;

    final url =
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}";

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body);

      if (data["estado"] == "en_domicilio" && mounted) {
        await LiveActivityService.instance.endConsulta(widget.consultaId!);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultaEnCursoScreen(
              consultaId: widget.consultaId!,
              profesionalId: widget.medicoId,
              pacienteUuid: widget.pacienteUuid,
              nombreProfesional: widget.nombreMedico,
              especialidad: data["especialidad"] ?? "Clínica médica",
              matricula: widget.matricula,
              motivo: widget.motivo,
              direccion: widget.direccion,
              horaInicio: DateFormat("HH:mm").format(DateTime.now()),
              tipo: widget.tipo,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    controller.setMapStyle(mapStyle);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _mapReady = true);
      }
    });
    _ajustarMapa();
  }

  void _ajustarMapa() {
    final controller = _mapController;
    final ubicacionMedico = _ubicacionMedico;
    if (controller == null || ubicacionMedico == null) return;

    final distanciaMetros = _distanciaEntrePuntosMetros(
      ubicacionMedico,
      widget.ubicacionPaciente,
    );

    if (distanciaMetros <= _distanciaMinimaConfiableMetros) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.ubicacionPaciente.latitude + 0.00045,
              widget.ubicacionPaciente.longitude,
            ),
            zoom: 16.4,
          ),
        ),
      );
      return;
    }

    final southwest = LatLng(
      ubicacionMedico.latitude < widget.ubicacionPaciente.latitude
          ? ubicacionMedico.latitude
          : widget.ubicacionPaciente.latitude,
      ubicacionMedico.longitude < widget.ubicacionPaciente.longitude
          ? ubicacionMedico.longitude
          : widget.ubicacionPaciente.longitude,
    );
    final northeast = LatLng(
      ubicacionMedico.latitude > widget.ubicacionPaciente.latitude
          ? ubicacionMedico.latitude
          : widget.ubicacionPaciente.latitude,
      ubicacionMedico.longitude > widget.ubicacionPaciente.longitude
          ? ubicacionMedico.longitude
          : widget.ubicacionPaciente.longitude,
    );

    try {
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southwest, northeast: northeast),
          180,
        ),
      );
    } catch (_) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              (ubicacionMedico.latitude + widget.ubicacionPaciente.latitude) / 2,
              (ubicacionMedico.longitude + widget.ubicacionPaciente.longitude) /
                  2,
            ),
            zoom: 13.4,
          ),
        ),
      );
    }
  }

  double _distanciaEntrePuntosMetros(LatLng a, LatLng b) {
    const metrosPorGrado = 111320.0;
    final dLat = (a.latitude - b.latitude) * metrosPorGrado;
    final dLng = (a.longitude - b.longitude) *
        metrosPorGrado *
        math.cos(((a.latitude + b.latitude) / 2) * math.pi / 180);
    return math.sqrt((dLat * dLat) + (dLng * dLng));
  }

  int _calcularEtaDesdeMetros(double metros) {
    if (metros <= 0) return 1;
    final velocidadPromedioMetrosPorMin = 450.0;
    return math.max(1, (metros / velocidadPromedioMetrosPorMin).ceil());
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId("paciente"),
        position: widget.ubicacionPaciente,
        infoWindow: const InfoWindow(title: "Tu ubicación"),
        icon: _pacienteMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    };

    if (_ubicacionMedico != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("profesional"),
          position: _ubicacionMedico!,
          infoWindow: InfoWindow(
            title: widget.nombreMedico,
            snippet: "En camino",
          ),
          icon: _profesionalMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
        ),
      );
    }

    return markers;
  }

  String _formatDistancia() {
    if (distanciaKm <= 0) return "Calculando";
    if (distanciaKm < 1) return "${(distanciaKm * 1000).round()} m";
    return "${distanciaKm.toStringAsFixed(1)} km";
  }

  String _formatEta() {
    if (etaMinutos <= 1) return "1 min";
    return "$etaMinutos min";
  }

  Widget _buildStep(String label, bool active, bool current) {
    final color =
        active ? const Color(0xFF25D7C8) : Colors.white.withOpacity(0.20);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: current ? 12 : 10,
            height: current ? 12 : 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.white.withOpacity(0.48),
              fontSize: 11,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: active
            ? const Color(0xFF25D7C8).withOpacity(0.80)
            : Colors.white.withOpacity(0.10),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF25D7C8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "EN CAMINO",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatKmRestantes() {
    if (distanciaActual <= 0) return "Calculando";
    if (distanciaActual < 1000) return "${distanciaActual.round()} m restantes";
    return "${(distanciaActual / 1000).toStringAsFixed(1)} km restantes";
  }

  String _formatEscala(double metros) {
    if (metros < 1000) return "${metros.round()} m";
    return "${(metros / 1000).toStringAsFixed(0)} km";
  }

  Widget _buildProximityBar() {
    final total = distanciaInicial > 0 ? distanciaInicial : distanciaActual;
    final progressValue = total > 0
        ? (1 - (distanciaActual / total)).clamp(0.0, 1.0)
        : progreso.clamp(0.0, 1.0);
    final tickBase = total > 0 ? total : 3000;
    final ticks = [
      tickBase,
      tickBase * 0.66,
      tickBase * 0.33,
      0.0,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Proximidad del profesional",
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              _formatKmRestantes(),
              style: const TextStyle(
                color: Color(0xFF25D7C8),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progressValue,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D7C8),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D7C8).withOpacity(0.30),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: ((progressValue * 100).clamp(0.0, 100.0) / 100) *
                    (MediaQuery.of(context).size.width - 92),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D7C8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D7C8).withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              "Salida",
              style: TextStyle(
                color: Colors.white.withOpacity(0.42),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            ...ticks.take(3).map(
                  (value) => Expanded(
                    child: Center(
                      child: Text(
                        _formatEscala(value.toDouble()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            const Spacer(),
            const Text(
              "Llegada",
              style: TextStyle(
                color: Color(0xFF25D7C8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF132A33).withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF25D7C8).withOpacity(0.92),
                    backgroundImage: _fotoProfesional != null
                        ? NetworkImage(_fotoProfesional!)
                        : null,
                    child: _fotoProfesional == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nombreMedico,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.tipo == "enfermero"
                              ? "Enfermero/a"
                              : "Clínico general",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            consultaId: widget.consultaId,
                            remitenteTipo: "paciente",
                            remitenteId: widget.pacienteUuid,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.chatCircleText,
                        color: Color(0xFF25D7C8),
                        size: 23,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProximityBar(),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildStep("Aceptado", true, false),
                  _buildStepLine(true),
                  _buildStep("En camino", true, true),
                  _buildStepLine(false),
                  _buildStep("En domicilio", false, false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        DocYaSnackbar.show(
          context,
          title: "Acción no permitida",
          message: "No podés salir hasta que llegue el profesional.",
          type: SnackType.warning,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF08171D),
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                opacity: _mapReady ? 1 : 0,
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: widget.ubicacionPaciente,
                    zoom: 10.2,
                  ),
                  mapType: MapType.normal,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  buildingsEnabled: false,
                  trafficEnabled: false,
                  indoorViewEnabled: false,
                  markers: _buildMarkers(),
                ),
              ),
            ),
            if (!_mapReady)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF08171D),
                        Color(0xFF12313B),
                        Color(0xFF0B2129),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0C1F27).withOpacity(0.28),
                        Colors.transparent,
                        const Color(0xFF0C1F27).withOpacity(0.42),
                      ],
                      stops: const [0.0, 0.24, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: IconButton(
                            onPressed: () {},
                            icon: Icon(
                              PhosphorIconsRegular.arrowLeft,
                              color: Colors.white.withOpacity(0.84),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Seguimiento en vivo",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Tiempo estimado",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.58),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatEta(),
                      style: const TextStyle(
                        color: Color(0xFF25D7C8),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildStatusChip(),
                    const Spacer(),
                    if (_ultimoRefresh != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          "Actualizado ${DateFormat("HH:mm:ss").format(_ultimoRefresh!)} · ${_formatDistancia()}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.50),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    _buildBottomSheet(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
