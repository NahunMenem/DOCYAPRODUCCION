import 'dart:convert';
import 'dart:ui';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/docya_snackbar.dart';

const kGoogleApiKey = "AIzaSyDVv_barlVwHJTgLF66dP4ESUffCBuS3uA";

class RegistrarDireccionScreen extends StatefulWidget {
  final String? nombreUsuario;
  final String? userId;
  final void Function(Map<String, dynamic> datos)? onSaved;
  final bool forceRequired;

  const RegistrarDireccionScreen({
    super.key,
    this.nombreUsuario,
    this.userId,
    this.onSaved,
    this.forceRequired = false,
  });

  @override
  State<RegistrarDireccionScreen> createState() =>
      _RegistrarDireccionScreenState();
}

class _RegistrarDireccionScreenState extends State<RegistrarDireccionScreen> {
  LatLng? selectedLocation;
  GoogleMapController? mapController;

  bool cargando = false;
  bool guardando = false;
  bool _loadedExistingAddress = false;

  final TextEditingController direccionCtrl = TextEditingController();
  final TextEditingController pisoCtrl = TextEditingController();
  final TextEditingController deptoCtrl = TextEditingController();
  final TextEditingController indicacionesCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();

  final String mapStyleDark = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#122932"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#E0F2F1"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#0B1A22"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#155E63"}]},
    {"featureType":"water","stylers":[{"color":"#0C2F3A"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _cargarDireccionGuardada();
  }

  @override
  void dispose() {
    direccionCtrl.dispose();
    pisoCtrl.dispose();
    deptoCtrl.dispose();
    indicacionesCtrl.dispose();
    telefonoCtrl.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController!.setMapStyle(mapStyleDark);
  }

  Future<void> _cargarDireccionGuardada() async {
    if (widget.userId == null) return;

    setState(() => cargando = true);

    try {
      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/direccion/mia/${widget.userId}",
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        selectedLocation = LatLng(
          (d["lat"] as num).toDouble(),
          (d["lng"] as num).toDouble(),
        );
        direccionCtrl.text = d["direccion"] ?? "";
        pisoCtrl.text = d["piso"] ?? "";
        deptoCtrl.text = d["depto"] ?? "";
        indicacionesCtrl.text = d["indicaciones"] ?? "";
        telefonoCtrl.text = d["telefono_contacto"] ?? "";
        _loadedExistingAddress = true;
      }
    } catch (e) {
      debugPrint("Error cargando dirección guardada: $e");
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _obtenerMiUbicacion() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        DocYaSnackbar.show(
          context,
          title: "GPS desactivado",
          message: "Activá tu ubicación para cargar tu dirección actual.",
          type: SnackType.warning,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        DocYaSnackbar.show(
          context,
          title: "Permiso requerido",
          message:
              "Necesitamos acceso a tu ubicación para ubicar al profesional con precisión.",
          type: SnackType.error,
        );
        return;
      }

      setState(() => cargando = true);

      final pos = await Geolocator.getCurrentPosition();
      selectedLocation = LatLng(pos.latitude, pos.longitude);
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(selectedLocation!, 17),
      );

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
        localeIdentifier: "es_AR",
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = [
          p.street,
          p.subThoroughfare,
        ].where((part) => (part ?? '').trim().isNotEmpty).join(' ');
        final locality = [
          p.locality,
          p.administrativeArea,
        ].where((part) => (part ?? '').trim().isNotEmpty).join(', ');
        direccionCtrl.text = [street, locality]
            .where((part) => part.trim().isNotEmpty)
            .join(', ');
      }

      if (mounted) {
        DocYaSnackbar.show(
          context,
          title: "Ubicación cargada",
          message: "Revisá la dirección y confirmala para continuar.",
          type: SnackType.success,
        );
      }
    } catch (e) {
      DocYaSnackbar.show(
        context,
        title: "No pudimos obtener tu ubicación",
        message: "Intentá nuevamente o buscá la dirección manualmente.",
        type: SnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => cargando = false);
      }
    }
  }

  Future<void> _buscarDetalleLugar(Prediction prediction) async {
    if (prediction.placeId == null) return;

    try {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=${prediction.placeId}&key=$kGoogleApiKey",
      );

      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data["status"] == "OK") {
        final loc = data["result"]["geometry"]["location"];
        selectedLocation = LatLng(
          (loc["lat"] as num).toDouble(),
          (loc["lng"] as num).toDouble(),
        );

        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(selectedLocation!, 17),
        );
        if (mounted) setState(() {});
      }
    } catch (e) {
      DocYaSnackbar.show(
        context,
        title: "No pudimos ubicar esa dirección",
        message: "Probá seleccionar otra opción del listado.",
        type: SnackType.error,
      );
    }
  }

  Future<void> _guardarDireccion() async {
    if (widget.userId == null) return;

    if (direccionCtrl.text.trim().isEmpty || selectedLocation == null) {
      DocYaSnackbar.show(
        context,
        title: "Dirección incompleta",
        message:
            "Buscá una dirección válida o usá tu ubicación actual antes de guardar.",
        type: SnackType.warning,
      );
      return;
    }

    setState(() => guardando = true);

    try {
      final res = await http.post(
        Uri.parse(
          "https://docya-railway-production.up.railway.app/direccion/guardar",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "lat": selectedLocation!.latitude,
          "lng": selectedLocation!.longitude,
          "direccion": direccionCtrl.text.trim(),
          "piso": pisoCtrl.text.trim(),
          "depto": deptoCtrl.text.trim(),
          "indicaciones": indicacionesCtrl.text.trim(),
          "telefono_contacto": telefonoCtrl.text.trim(),
        }),
      );

      if (res.statusCode != 200) {
        DocYaSnackbar.show(
          context,
          title: "No se pudo guardar",
          message: "Intentá nuevamente en unos segundos.",
          type: SnackType.error,
        );
        return;
      }

      final datos = {
        "direccion": direccionCtrl.text.trim(),
        "piso": pisoCtrl.text.trim(),
        "depto": deptoCtrl.text.trim(),
        "indicaciones": indicacionesCtrl.text.trim(),
        "telefono": telefonoCtrl.text.trim(),
        "lat": selectedLocation!.latitude,
        "lng": selectedLocation!.longitude,
      };

      DocYaSnackbar.show(
        context,
        title: _loadedExistingAddress
            ? "Dirección actualizada"
            : "Dirección guardada",
        message: _loadedExistingAddress
            ? "Tu dirección quedó actualizada correctamente."
            : "Ya podés continuar usando DocYa.",
        type: SnackType.success,
      );

      if (widget.onSaved != null) {
        widget.onSaved!(datos);
      } else if (mounted) {
        Navigator.pop(context, datos);
      }
    } finally {
      if (mounted) {
        setState(() => guardando = false);
      }
    }
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      prefixIcon: icon == null
          ? null
          : Icon(
              icon,
              color: const Color(0xFF14B8A6),
            ),
      border: InputBorder.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => !widget.forceRequired,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: !widget.forceRequired,
          centerTitle: true,
          title: Text(
            _loadedExistingAddress
                ? "Actualizar dirección"
                : "Confirmar dirección",
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    colors: [
                      Color(0xFF0F2027),
                      Color(0xFF203A43),
                      Color(0xFF2C5364),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? null : Colors.white,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hola ${widget.nombreUsuario ?? "usuario"}",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.forceRequired
                              ? "Antes de continuar necesitamos tu dirección para ubicar al profesional más cercano."
                              : "Revisá tu ubicación y dejá instrucciones claras para que el profesional llegue sin demoras.",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF14B8A6).withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF14B8A6),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Usamos esta dirección para mostrarte la cobertura disponible y asignar al profesional más cercano.",
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _obtenerMiUbicacion,
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      label: const Text(
                        "Usar mi ubicación actual",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _glassCard(
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: direccionCtrl,
                      googleAPIKey: kGoogleApiKey,
                      debounceTime: 600,
                      countries: const ["ar"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) async {
                        await _buscarDetalleLugar(prediction);
                      },
                      inputDecoration: _inputDecoration(
                        label: "Buscar dirección",
                        icon: Icons.search_rounded,
                      ),
                      itemClick: (Prediction prediction) async {
                        direccionCtrl.text = prediction.description ?? "";
                        direccionCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: direccionCtrl.text.length),
                        );
                        await _buscarDetalleLugar(prediction);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      height: 210,
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target: selectedLocation ??
                              const LatLng(-34.6037, -58.3816),
                          zoom: selectedLocation != null ? 16 : 12,
                        ),
                        markers: selectedLocation == null
                            ? {}
                            : {
                                Marker(
                                  markerId: const MarkerId("direccion"),
                                  position: selectedLocation!,
                                ),
                              },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _glassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: pisoCtrl,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _inputDecoration(
                            label: "Piso",
                            icon: Icons.apartment_rounded,
                          ),
                        ),
                        const Divider(height: 1),
                        TextField(
                          controller: deptoCtrl,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _inputDecoration(
                            label: "Depto",
                            icon: Icons.meeting_room_outlined,
                          ),
                        ),
                        const Divider(height: 1),
                        TextField(
                          controller: telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _inputDecoration(
                            label: "Teléfono de contacto",
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const Divider(height: 1),
                        TextField(
                          controller: indicacionesCtrl,
                          maxLines: 3,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: _inputDecoration(
                            label: "Indicaciones para llegar",
                            icon: Icons.sticky_note_2_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: guardando ? null : _guardarDireccion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _loadedExistingAddress
                                  ? "Guardar cambios"
                                  : "Guardar y continuar",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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
    );
  }
}
