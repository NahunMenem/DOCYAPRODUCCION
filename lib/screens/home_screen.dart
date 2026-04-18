import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'solicitud_enfermero_screen.dart';
import 'filtro_medico_screen.dart';
import '../widgets/bottom_nav.dart';
import 'perfil_screen.dart';
import 'consultas_screen.dart';
import 'medicacion_screen.dart';
import 'recetas_screen.dart';
import 'registrar_direccion_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../widgets/noticias_carousel.dart';
import 'chat_ia_screen.dart';
import '../services/medication_reminder_service.dart';
import '../services/medication_service.dart';
import 'MedicoEnCaminoScreen.dart';
import 'EnfermeroEnCaminoScreen.dart';
import 'consulta_en_curso_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? nombreUsuario;
  final String? userId;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    this.nombreUsuario,
    this.userId,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? _nombreUsuario;
  String? _userId;
  String? _userToken;
  bool cargando = true;
  bool tieneDireccion = false;
  bool _addressGateShown = false;
  LatLng? selectedLocation;
  GoogleMapController? mapController;
  int _selectedIndex = 0;

  final TextEditingController direccionCtrl = TextEditingController();
  final TextEditingController pisoCtrl = TextEditingController();
  final TextEditingController deptoCtrl = TextEditingController();
  final TextEditingController indicacionesCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // 🎨 Estilo de mapa DocYa
  // 🎨 Estilo de mapa DocYa (mejor visibilidad)
  final String docyaMapStyle = '''
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
    WidgetsBinding.instance.addObserver(this);
    _cargarSesion();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  /// Cuando el paciente vuelve la app al frente (sin haber tapeado la
  /// notificación), verificamos si hay una consulta activa asignada
  /// y navegamos automáticamente.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarConsultaActiva();
    }
  }

  Future<void> _verificarConsultaActiva() async {
    debugPrint("🔎 Home paciente: verificando consulta activa");
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? data;
    int? consultaId;

    // 1️⃣ Intentar con el ID guardado localmente
    final consultaIdStr = prefs.getString("consulta_activa_id");
    debugPrint("🔎 Home paciente: consulta_activa_id local=$consultaIdStr");
    if (consultaIdStr != null && consultaIdStr.isNotEmpty) {
      final id = int.tryParse(consultaIdStr);
      if (id != null) {
        try {
          final resp = await http.get(
            Uri.parse(
              "https://docya-railway-production.up.railway.app/consultas/$id",
            ),
          );
          if (resp.statusCode == 200) {
            data = jsonDecode(resp.body) as Map<String, dynamic>;
            consultaId = id;
            debugPrint(
                "🔎 Home paciente: consulta local encontrada id=$consultaId estado=${data["estado"]}");
          }
        } catch (_) {}
      }
    }

    // 2️⃣ Fallback: consultar backend por UUID (cubre asignaciones manuales
    //    donde el ID local quedó desactualizado o nunca se guardó)
    if (data == null && _userId != null && _userId!.isNotEmpty) {
      debugPrint("🔎 Home paciente: fallback backend userId=$_userId");
      try {
        final resp = await http.get(
          Uri.parse(
            "https://docya-railway-production.up.railway.app/pacientes/$_userId/consulta_activa",
          ),
        );
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          if (body["activa"] == true) {
            consultaId = body["id"] as int;
            data = body;
            data["paciente_uuid"] = _userId;
            await prefs.setString("consulta_activa_id", consultaId.toString());
            debugPrint(
                "💾 Home paciente: consulta_activa_id actualizado desde backend=$consultaId");
          }
        }
      } catch (_) {}
    }

    if (data == null || consultaId == null) return;

    // Variables non-null para satisfacer al type checker de Dart
    final d = data!;
    final cid = consultaId!;

    final estado = (d["estado"] ?? "").toString();
    final tipo = (d["tipo"] ?? "medico").toString();
    final pacienteUuid = (d["paciente_uuid"] ?? _userId ?? "").toString();
    debugPrint(
        "🧭 Home paciente: navegar consultaId=$cid estado=$estado tipo=$tipo");

    if (!mounted) return;

    if (estado == "aceptada" || estado == "en_camino") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => tipo == "enfermero"
              ? EnfermeroEnCaminoScreen(
                  direccion: d["direccion"] ?? "",
                  ubicacionPaciente: LatLng(
                    (d["lat"] as num?)?.toDouble() ?? 0,
                    (d["lng"] as num?)?.toDouble() ?? 0,
                  ),
                  motivo: d["motivo"] ?? "",
                  enfermeroId: d["medico_id"],
                  nombreEnfermero: d["medico_nombre"] ?? "Profesional asignado",
                  matricula: d["medico_matricula"] ?? "N/A",
                  consultaId: cid,
                  pacienteUuid: pacienteUuid,
                )
              : MedicoEnCaminoScreen(
                  direccion: d["direccion"] ?? "",
                  ubicacionPaciente: LatLng(
                    (d["lat"] as num?)?.toDouble() ?? 0,
                    (d["lng"] as num?)?.toDouble() ?? 0,
                  ),
                  motivo: d["motivo"] ?? "",
                  medicoId: d["medico_id"],
                  nombreMedico: d["medico_nombre"] ?? "Profesional asignado",
                  matricula: d["medico_matricula"] ?? "N/A",
                  consultaId: cid,
                  pacienteUuid: pacienteUuid,
                  tipo: tipo,
                ),
        ),
        (route) => false,
      );
      return;
    }

    if (estado == "en_domicilio" || estado == "en_curso") {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultaEnCursoScreen(
            consultaId: cid,
            profesionalId: d["medico_id"],
            pacienteUuid: pacienteUuid,
            nombreProfesional: d["medico_nombre"] ?? "Profesional asignado",
            especialidad: d["especialidad"] ?? "",
            matricula: d["medico_matricula"] ?? "N/A",
            motivo: d["motivo"] ?? "",
            direccion: d["direccion"] ?? "",
            horaInicio: DateFormat("HH:mm").format(DateTime.now()),
            tipo: tipo,
          ),
        ),
        (route) => false,
      );
      return;
    }

    // Estado terminal: limpiar el ID guardado
    if (estado == "finalizada" ||
        estado == "cancelada" ||
        estado == "rechazada") {
      await prefs.remove("consulta_activa_id");
    }
  }

  Future<void> _cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuario = widget.nombreUsuario ?? prefs.getString("nombreUsuario");
      _userId = widget.userId ?? prefs.getString("userId");
      _userToken = prefs.getString("auth_token");
    });

    if (_userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, "/login");
      });
    } else {
      _syncMedicationReminders();
      _cargarDireccionGuardada();
    }
  }

  Future<void> _syncMedicationReminders() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      final agenda = await MedicationService.getAgenda(_userId!, dias: 30);
      await MedicationReminderService.syncAgenda(agenda);
    } catch (_) {
      // No bloqueamos el home si el pastillero falla.
    }
  }

  Future<void> _cargarDireccionGuardada() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/direccion/mia/${_userId}");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        selectedLocation = LatLng(data["lat"], data["lng"]);
        direccionCtrl.text = data["direccion"] ?? "";
        pisoCtrl.text = data["piso"] ?? "";
        deptoCtrl.text = data["depto"] ?? "";
        indicacionesCtrl.text = data["indicaciones"] ?? "";
        telefonoCtrl.text = data["telefono_contacto"] ?? "";
        tieneDireccion = true;
        cargando = false;
      });

      // 📍 centramos cámara
      if (mapController != null && selectedLocation != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(selectedLocation!, 16),
        );
      }
    } else {
      setState(() {
        tieneDireccion = false;
        cargando = false;
      });
      _abrirRegistroDireccionObligatorio();
    }
  }

  Future<void> _abrirRegistroDireccionObligatorio() async {
    if (!mounted || _addressGateShown || _userId == null) return;
    _addressGateShown = true;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrarDireccionScreen(
          nombreUsuario: _nombreUsuario,
          userId: _userId,
          forceRequired: true,
        ),
      ),
    );

    _addressGateShown = false;

    if (!mounted) return;

    await _cargarDireccionGuardada();

    if (result != null) {
      _mostrarSnackBar(
        context,
        "Dirección guardada correctamente",
      );
    }
  }

  void _mostrarSnackBar(BuildContext context, String mensaje,
      {bool exito = true}) {
    final color = exito ? const Color(0xFF14B8A6) : Colors.redAccent;
    final icono =
        exito ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.warningCircle;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icono, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget glassCard({required Widget child, EdgeInsets? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isDark ? Border.all(color: Colors.white24) : null,
          ),
          child: child,
        ),
      ),
    );
  }

  // 🔹 Botones de servicio
  Widget _serviceButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Gradient? gradient,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _animationController.reverse(),
      onTapUp: (_) {
        _animationController.forward();
        onTap();
      },
      onTapCancel: () => _animationController.forward(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  colors: [
                    color.withOpacity(0.95),
                    color.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                  ),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ??
                          (label == "Emergencia"
                              ? "Asistencia inmediata"
                              : "Cuidado profesional en casa"),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                PhosphorIconsFill.arrowUpRight,
                size: 18,
                color: Colors.white.withOpacity(0.92),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidacionProfesionales() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF10242B),
                  Color(0xFF16343D),
                ]
              : const [
                  Colors.white,
                  Color(0xFFF6FFFD),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.22 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.12 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Todos nuestros profesionales estan validados por',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 86,
            height: 86,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.network(
              'https://res.cloudinary.com/dqsacd9ez/image/upload/v1775043651/logosisa_dxtx66.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitTile(
    IconData icon,
    String title, [
    Color accentColor = const Color(0xFF14B8A6),
  ]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF10242B),
                  Color(0xFF16343D),
                ]
              : const [
                  Colors.white,
                  Color(0xFFF5FFFD),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.24 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.14 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accentColor.withOpacity(isDark ? 0.18 : 0.12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaHomePrincipal() {
    return _fondoGradiente(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(PhosphorIconsFill.handWaving,
                                color: Color(0xFF14B8A6), size: 20),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Hola, ${(_nombreUsuario ?? "Usuario").split(' ').first}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF14B8A6),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "¿Qué necesitás hoy?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white60
                                    : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge disponibilidad
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF14B8A6),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          "24hs activo",
                          style: TextStyle(
                            color: Color(0xFF14B8A6),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 🔹 Botón principal premium
              GestureDetector(
                onTap: () {
                  if (selectedLocation != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FiltroMedicoScreen(
                          direccion: direccionCtrl.text,
                          ubicacion: selectedLocation!,
                        ),
                      ),
                    );
                  } else {
                    _mostrarSnackBar(
                        context, 'Seleccioná una ubicación primero',
                        exito: false);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0EA896),
                        Color(0xFF14B8A6),
                        Color(0xFF2DD4BF),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.52),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          PhosphorIconsFill.firstAid,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solicitar médico ahora',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Atención a domicilio · 24hs',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          PhosphorIconsFill.arrowRight,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🤖 Card premium Chat IA
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatIAScreen(
                        direccion: tieneDireccion ? direccionCtrl.text : null,
                        ubicacion: selectedLocation,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0D4F4A),
                        Color(0xFF0F6B61),
                        Color(0xFF14B8A6),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              PhosphorIconsFill.sparkle,
                              color: Colors.white,
                              size: 29,
                            ),
                            Positioned(
                              top: 10,
                              right: 8,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF99F6E4),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF0F6B61),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.sparkle,
                                  color: Color(0xFF0F6B61),
                                  size: 8.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Consultar con DocYa IA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Síntomas, dudas, consejos · gratis',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Text(
                              '(gratis)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(
                            PhosphorIconsFill.arrowRight,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dirección guardada
              glassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0F766E),
                                Color(0xFF14B8A6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            PhosphorIconsFill.mapPin,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tu dirección actual',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF14B8A6),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                direccionCtrl.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (pisoCtrl.text.isNotEmpty ||
                        deptoCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Piso: ${pisoCtrl.text.isEmpty ? "-" : pisoCtrl.text}  ·  Depto: ${deptoCtrl.text.isEmpty ? "-" : deptoCtrl.text}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegistrarDireccionScreen(
                                nombreUsuario: _nombreUsuario,
                                userId: _userId,
                              ),
                            ),
                          );

                          if (mounted) {
                            await _cargarDireccionGuardada();

                            if (selectedLocation != null &&
                                mapController != null) {
                              mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                    selectedLocation!, 16),
                              );
                            }

                            _mostrarSnackBar(
                              context,
                              "Dirección actualizada correctamente",
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF14B8A6).withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                PhosphorIconsFill.pencilSimple,
                                color: Color(0xFF14B8A6),
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Cambiar dirección",
                                style: TextStyle(
                                  color: Color(0xFF14B8A6),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 🗺️ Mapa DocYa con radar
              // 🗺️ Mapa DocYa con radar en la ubicación
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                          controller.setMapStyle(docyaMapStyle);
                          if (selectedLocation != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(selectedLocation!, 16),
                            );
                          }
                        },
                        initialCameraPosition: CameraPosition(
                          target: selectedLocation ??
                              const LatLng(-34.6037, -58.3816),
                          zoom: 14,
                        ),
                        markers: const {},
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                      ),

                      // Radar / ubicación destacada
                      if (selectedLocation != null)
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            Tween(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Curves.easeInOut,
                              ),
                            )
                          ]),
                          builder: (context, _) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeOut,
                              onEnd: () => setState(() {}),
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset.zero,
                                  child: Container(
                                    width: 60 + (value * 70),
                                    height: 60 + (value * 70),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF14B8A6)
                                          .withOpacity((1 - value) * 0.22),
                                      border: Border.all(
                                        color: const Color(0xFF2DD4BF)
                                            .withOpacity((1 - value) * 0.45),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      if (selectedLocation != null)
                        IgnorePointer(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF14B8A6).withOpacity(0.45),
                                  blurRadius: 22,
                                  spreadRadius: 4,
                                ),
                              ],
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xFFECFEFF),
                                  Color(0xFF67E8F9),
                                  Color(0xFF14B8A6),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.92),
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Column(
                children: [
                  _serviceButton(
                    context,
                    icon: PhosphorIconsFill.syringe,
                    label: "Enfermero",
                    color: const Color(0xFF14B8A6),
                    subtitle: "Cuidados y controles en tu domicilio",
                    onTap: () {
                      if (selectedLocation != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SolicitudEnfermeroScreen(
                              direccion: direccionCtrl.text,
                              ubicacion: selectedLocation!,
                            ),
                          ),
                        );
                      } else {
                        _mostrarSnackBar(
                            context, "Seleccioná una ubicación primero",
                            exito: false);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _serviceButton(
                    context,
                    icon: PhosphorIconsFill.pill,
                    label: "Medicacion",
                    color: const Color(0xFF0EA5E9),
                    subtitle: "Recordatorios y seguimiento diario",
                    onTap: () {
                      if ((_userId ?? '').isEmpty) {
                        _mostrarSnackBar(
                          context,
                          "No pudimos identificar tu sesion",
                          exito: false,
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MedicacionScreen(
                            pacienteUuid: _userId!,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _serviceButton(
                    context,
                    icon: PhosphorIconsFill.warningCircle,
                    label: "Emergencia",
                    color: Colors.redAccent,
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.red],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    onTap: () async {
                      final Uri callUri = Uri(scheme: 'tel', path: '911');
                      if (await canLaunchUrl(callUri)) {
                        await launchUrl(callUri);
                      } else {
                        _mostrarSnackBar(
                            context, "No se pudo iniciar la llamada",
                            exito: false);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Beneficios
              Row(
                children: [
                  Expanded(
                    child: _benefitTile(
                      PhosphorIconsFill.lightning,
                      "Atención rápida",
                      const Color(0xFF14B8A6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _benefitTile(
                      PhosphorIconsFill.shieldCheck,
                      "Pago seguro",
                      const Color(0xFF0EA5E9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _benefitTile(
                      PhosphorIconsFill.star,
                      "Médicos calificados",
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildValidacionProfesionales(),
              const SizedBox(height: 24),

              // Sección Noticias de salud
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Noticias de salud",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF14B8A6).withOpacity(0.20),
                      ),
                    ),
                    child: const Text(
                      "DocYa Info",
                      style: TextStyle(
                        color: Color(0xFF14B8A6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const NoticiasCarousel(),
              const SizedBox(height: 32),

              // Sección Zonas habilitadas
              _seccionZonas(),
              const SizedBox(height: 24),
              _buildHomeFooter(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentYear = DateTime.now().year;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF10242B),
                  Color(0xFF16343D),
                ]
              : const [
                  Colors.white,
                  Color(0xFFF6FFFD),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.18 : 0.10),
        ),
      ),
      child: Column(
        children: [
          Text(
            '\u00A9 $currentYear DocYa \u2014 Todos los derechos reservados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, List<Map<String, String>>>> _fetchZonas() async {
    final res = await http.get(
      Uri.parse(
          'https://docya-railway-production.up.railway.app/zonas-cobertura'),
    );
    if (res.statusCode != 200) throw Exception('Error al cargar zonas');
    final data = jsonDecode(res.body);
    List<Map<String, String>> parse(List d) => d
        .map<Map<String, String>>((z) => {
              'nombre': z['nombre'] ?? '',
              'detalle': z['detalle'] ?? '',
            })
        .toList();
    return {
      'activas': parse(data['activas']),
      'proximas': parse(data['proximas']),
    };
  }

  Widget _seccionZonas() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF14B8A6);

    return FutureBuilder<Map<String, List<Map<String, String>>>>(
      future: _fetchZonas(),
      builder: (context, snapshot) {
        final zonasActivas = snapshot.data?['activas'] ?? [];
        final zonasProximas = snapshot.data?['proximas'] ?? [];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF10242B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zonas de cobertura',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hoy operamos en Buenos Aires.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              _zonasChips(
                isDark: isDark,
                title: 'Disponible ahora',
                accentColor: accent,
                zonas: zonasActivas,
                emptyText: 'Todavía no hay zonas activas para mostrar.',
                loading: snapshot.connectionState == ConnectionState.waiting,
              ),
              if (zonasProximas.isNotEmpty) ...[
                const SizedBox(height: 14),
                _zonasChips(
                  isDark: isDark,
                  title: 'Próximamente',
                  accentColor:
                      isDark ? Colors.white70 : const Color(0xFF5B6770),
                  zonas: zonasProximas,
                  emptyText: 'Sin zonas próximas por ahora.',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _zonasChips({
    required bool isDark,
    required String title,
    required Color accentColor,
    required List<Map<String, String>> zonas,
    required String emptyText,
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.14 : 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(
                  color: Color(0xFF14B8A6),
                  strokeWidth: 2,
                ),
              ),
            )
          else if (zonas.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: zonas.map((z) {
                final nombre = z['nombre'] ?? '';
                final detalle = z['detalle'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withOpacity(0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (detalle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: activeColor(accentColor, isDark),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Color activeColor(Color accentColor, bool isDark) {
    return accentColor == Colors.white70
        ? (isDark ? Colors.white60 : Colors.black45)
        : accentColor;
  }

  Widget _fondoGradiente({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F4F8), Color(0xFFF3F8FA), Color(0xFFF0F4F8)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -100,
              top: -60,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(20, 184, 166, 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: const Color(0xFF04151C),
      child: Stack(
        children: [
          Positioned(
            left: -140,
            top: 140,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.fromRGBO(0, 210, 255, 0.16),
                      Color.fromRGBO(0, 210, 255, 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -150,
            top: -10,
            child: IgnorePointer(
              child: Container(
                width: 430,
                height: 430,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.fromRGBO(58, 134, 255, 0.16),
                      Color.fromRGBO(58, 134, 255, 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: AppBar(
              elevation: 0,
              centerTitle: true,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF04151C).withOpacity(0.75)
                  : Colors.white.withOpacity(0.72),
              surfaceTintColor: Colors.transparent,
              title: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? "assets/logoblanco.png"
                    : "assets/logonegro.png",
                height: 34,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? PhosphorIconsFill.sunDim
                        : PhosphorIconsFill.moonStars,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                  onPressed: () {
                    widget.onToggleTheme();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _vistaHomePrincipal(),
          RecetasScreen(
            pacienteUuid: _userId ?? "",
            token: _userToken ?? "",
          ),
          ConsultasScreen(
            pacienteUuid: _userId ?? "",
          ),
          PerfilScreen(
            userId: _userId ?? "",
          ),
        ],
      ),
      bottomNavigationBar: DocYaBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
        isHomeStyle: true,
      ),
    );
  }
}
