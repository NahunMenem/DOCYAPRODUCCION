import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'consulta_en_curso_screen.dart';
import 'valorar_profesional_screen.dart';

class EnfermeroEnCaminoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacionPaciente;
  final String motivo;
  final int enfermeroId;
  final String nombreEnfermero;
  final String matricula;
  final int consultaId;
  final String pacienteUuid;

  const EnfermeroEnCaminoScreen({
    super.key,
    required this.direccion,
    required this.ubicacionPaciente,
    required this.motivo,
    required this.enfermeroId,
    required this.nombreEnfermero,
    required this.matricula,
    required this.consultaId,
    required this.pacienteUuid,
  });

  @override
  State<EnfermeroEnCaminoScreen> createState() =>
      _EnfermeroEnCaminoScreenState();
}

class _EnfermeroEnCaminoScreenState extends State<EnfermeroEnCaminoScreen> {
  late GoogleMapController _mapController;
  Timer? _timer;
  LatLng? enfermeroLocation;
  double? tiempoEstimado;
  BitmapDescriptor? enfermeroIcon;
  Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};

  final String uberMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{"color": "#122932"}]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#E0F2F1"}]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#0B1A22"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#155E63"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#0F3E45"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{"color": "#18A999"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#0D2D32"}]
    },
    {
      "featureType": "water",
      "stylers": [{"color": "#0C2F3A"}]
    },
    {
      "featureType": "poi",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "transit",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry.stroke",
      "stylers": [{"color": "#134E4A"}]
    }
  ]
  ''';


  @override
  void initState() {
    super.initState();
    _cargarIconoEnfermero();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      _getUbicacionEnfermero();
      _checkEstadoConsulta();
    });
  }

  Future<void> _cargarIconoEnfermero() async {
    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(64, 64)),
      "assets/enfermero.png", // 👈 poné un ícono de enfermero/enfermera
    );
    setState(() => enfermeroIcon = icon);
  }

  Future<void> _getUbicacionEnfermero() async {
    final url =
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/ubicacion_medico";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nuevaUbicacion = LatLng(data["lat"], data["lng"]);

        setState(() {
          enfermeroLocation = nuevaUbicacion;
        });

        await _dibujarRuta();
        _calcularTiempo();
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación enfermero: $e");
    }
  }

  Future<void> _checkEstadoConsulta() async {
    final url =
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["estado"] == "en_domicilio" && mounted) {
          final horaInicio = DateFormat("HH:mm").format(DateTime.now());

          await http.patch(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"hora_inicio": horaInicio}),
          );

          _timer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ConsultaEnCursoScreen(
                consultaId: widget.consultaId,
                profesionalId: widget.enfermeroId,
                pacienteUuid: widget.pacienteUuid,
                nombreProfesional: widget.nombreEnfermero,
                especialidad: data["especialidad"] ?? "Enfermería",
                matricula: widget.matricula,
                motivo: widget.motivo,
                direccion: widget.direccion,
                horaInicio: horaInicio,
                tipo: "enfermero",
              ),
            ),
          );
        }

        if (data["estado"] == "finalizada" && mounted) {
          final horaFin = DateFormat("HH:mm").format(DateTime.now());

          await http.patch(
            Uri.parse(url),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"hora_fin": horaFin}),
          );

          _timer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ValorarProfesionalScreen(
                consultaId: widget.consultaId,
                pacienteUuid: widget.pacienteUuid,
                profesionalId: widget.enfermeroId,
                tipo: "enfermero",
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error revisando estado consulta: $e");
    }
  }

  Future<void> _dibujarRuta() async {
    if (enfermeroLocation == null) return;

    const String apiKey = "AIzaSyClH5_b6XATyG2o9cFj8CKGS1E-bzrFFhU";
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${enfermeroLocation!.latitude},${enfermeroLocation!.longitude}"
        "&destination=${widget.ubicacionPaciente.latitude},${widget.ubicacionPaciente.longitude}"
        "&mode=driving&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data["routes"].isNotEmpty) {
      final puntos = data["routes"][0]["overview_polyline"]["points"];
      final decodedPoints = PolylinePoints.decodePolyline(puntos);

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId("ruta"),
            color: const Color(0xFF11B5B0),
            width: 6,
            points: decodedPoints
                .map((e) => LatLng(e.latitude, e.longitude))
                .toList(),
          ),
        };

        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId("paciente"),
          position: widget.ubicacionPaciente,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: "Tu domicilio"),
        ));
        if (enfermeroIcon != null && enfermeroLocation != null) {
          _markers.add(Marker(
            markerId: const MarkerId("enfermero"),
            position: enfermeroLocation!,
            icon: enfermeroIcon!,
            infoWindow: const InfoWindow(title: "Enfermero en camino"),
          ));
        }
      });
    }
  }

  void _calcularTiempo() {
    if (enfermeroLocation == null) return;
    double distanciaKm = _haversine(
      enfermeroLocation!.latitude,
      enfermeroLocation!.longitude,
      widget.ubicacionPaciente.latitude,
      widget.ubicacionPaciente.longitude,
    );
    setState(() {
      tiempoEstimado = distanciaKm / 0.5;
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  @override
  void dispose() {
    _mapController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _llamarEnfermero() async {
    final Uri tel = Uri(scheme: "tel", path: "123456789");
    if (await canLaunchUrl(tel)) {
      await launchUrl(tel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo iniciar la llamada 📞")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int minutos = (tiempoEstimado ?? 0).ceil();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF11B5B0),
        title: const Text("Enfermero en camino"),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController.setMapStyle(uberMapStyle);
            },
            initialCameraPosition: CameraPosition(
              target: widget.ubicacionPaciente,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundImage: AssetImage("assets/enfermero.jpg"),
                        radius: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.nombreEnfermero,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text("Matrícula: ${widget.matricula}",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black54)),
                            Text("⏳ Llegada estimada: $minutos min",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: _llamarEnfermero,
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11B5B0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("📞 Contactando al enfermero...")),
                        );
                      },
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text(
                        "Enviar mensaje",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
