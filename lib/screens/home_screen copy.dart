import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'solicitud_enfermero_screen.dart';
import 'package:google_nav_bar/google_nav_bar.dart'; // 👉 Agregá en pubspec.yaml
import 'filtro_medico_screen.dart';
import '../widgets/bottom_nav.dart';
import 'perfil_screen.dart';
import 'consultas_screen.dart';
import 'recetas_screen.dart';
import 'package:flutter/services.dart'; // 👈 para HapticFeedback
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart'; // 👈 para la barra curva
import 'registrar_direccion_screen.dart'; // <-- nueva importación


// (se eliminaron imports de google_places_flutter porque la pantalla de dirección ahora está en otro archivo)

class HomeScreen extends StatefulWidget {
  final String? nombreUsuario;
  final String? userId;
  final VoidCallback onToggleTheme; // 👈 Nuevo: alternar tema

  const HomeScreen({
    super.key,
    this.nombreUsuario,
    this.userId,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _nombreUsuario;
  String? _userId;

  LatLng? selectedLocation;
  late GoogleMapController mapController;
  bool cargando = true;
  bool tieneDireccion = false;
  String? _userToken;
  int _selectedIndex = 0;

  final TextEditingController direccionCtrl = TextEditingController();
  final TextEditingController pisoCtrl = TextEditingController();
  final TextEditingController deptoCtrl = TextEditingController();
  final TextEditingController indicacionesCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();

  // 🔹 Estilo Uber Dark (mapa negro)
  final String uberMapStyle = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#212121"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#3c3c3c"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _cargarSesion();
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
      _cargarDireccionGuardada();
    }
  }

  Future<void> _guardarSesion(String nombre, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("nombreUsuario", nombre);
    await prefs.setString("userId", id);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    mapController.setMapStyle(uberMapStyle);
  }

  Future<void> _cargarDireccionGuardada() async {
    final url = Uri.parse(
      "https://docya-railway-production.up.railway.app/direccion/mia/${_userId}",
    );

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
    } else {
      setState(() {
        tieneDireccion = false;
        cargando = false;
      });
    }
  }

  /// 🔹 SnackBar flotante y moderno estilo DocYa
  void _mostrarSnackBar(BuildContext context, String mensaje, {bool exito = true}) {
    final color = exito ? const Color(0xFF14B8A6) : Colors.redAccent;
    final icono = exito ? Icons.check_circle : Icons.error;

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


  // 🔹 Card estilo glass
  Widget glassCard({
    required Widget child,
    EdgeInsets? padding,
    double? minHeight,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints:
              minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isDark
                ? Border.all(color: Colors.white24, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  // ------------------ VISTA HOME PRINCIPAL ------------------
  Widget _vistaHomePrincipal() {
    return _fondoGradiente(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hola, ${_nombreUsuario ?? "Usuario"}, ¿qué necesitás hoy?",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Botón principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("❌ Seleccioná una ubicación primero"),
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.local_hospital,
                          color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        "Solicitar médico ahora",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Dirección guardada
              glassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(direccionCtrl.text,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text("Piso: ${pisoCtrl.text} - Depto: ${deptoCtrl.text}",
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => tieneDireccion = false),
                      child: const Text("Cambiar",
                          style: TextStyle(
                              color: Color(0xFF14B8A6),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 150,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: selectedLocation ??
                          const LatLng(-34.6037, -58.3816),
                      zoom: selectedLocation != null ? 16 : 14,
                    ),
                    markers: selectedLocation != null
                        ? {
                            Marker(
                                markerId: const MarkerId("sel"),
                                position: selectedLocation!)
                          }
                        : {},
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Atajos
              Row(
                children: [
                  Expanded(
                    child: _serviceTile(
                      Icons.vaccines,
                      "Enfermero",
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("❌ Seleccioná una ubicación primero"),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: _serviceTile(Icons.emergency, "Emergencia",
                        color: Colors.redAccent, onTap: () async {
                      final Uri callUri = Uri(scheme: 'tel', path: '911');
                      if (await canLaunchUrl(callUri)) {
                        await launchUrl(callUri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("❌ No se pudo iniciar la llamada")),
                        );
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Beneficios
              // Beneficios modernos
              _benefitsSection(),

              const SizedBox(height: 24),

              Text("Noticias de salud",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              glassCard(
                minHeight: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("💉 Campaña contra el dengue",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      "Ya comenzó la vacunación contra el dengue. Consultá a tu médico.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              glassCard(
                minHeight: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("🩺 Chequeos anuales",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      "No olvides hacerte un control clínico una vez al año.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ Tiles ------------------
  Widget _serviceTile(IconData icon, String title,
      {VoidCallback? onTap, Color color = const Color(0xFF14B8A6)}) {
    return glassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _benefitTile(IconData icon, String title) {
    final color = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return glassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  // 🔹 Nueva sección moderna de beneficios estilo DocYa
// 🔹 Nueva sección moderna de beneficios (revisada)
  Widget _benefitsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final beneficios = [
      {
        "icon": Icons.flash_on_rounded,
        "label": "Atención rápida",
        "color": const Color(0xFF14B8A6),
      },
      {
        "icon": Icons.verified_user_rounded,
        "label": "Pago seguro",
        "color": Colors.lightBlueAccent,
      },
      {
        "icon": Icons.medical_services_rounded,
        "label": "Médicos calificados",
        "color": Colors.deepPurpleAccent,
      },
    ];

    return Row(
      children: beneficios.map((b) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF5F7FA),
              boxShadow: [
                BoxShadow(
                  color: (b["color"] as Color).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: (b["color"] as Color).withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        (b["color"] as Color).withOpacity(0.9),
                        (b["color"] as Color).withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    b["icon"] as IconData,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  b["label"] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }




  // 🔹 Fondo gradiente global
  Widget _fondoGradiente({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return Container(color: const Color(0xFFF5F5F5), child: child);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }

   // ------------------ BUILD ------------------
  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0F2027),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Image.asset("assets/logoblanco.png", height: 36),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6, color: Colors.white),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),

      // ---------------- BODY ----------------
      body: (() {
        if (!tieneDireccion) {
          // mostramos la pantalla separada pero pasamos un callback para
          // actualizar el estado del Home cuando se guarde la dirección.
          return RegistrarDireccionScreen(
            nombreUsuario: _nombreUsuario,
            userId: _userId,
            onSaved: (datos) {
              setState(() {
                direccionCtrl.text = datos['direccion'] ?? "";
                pisoCtrl.text = datos['piso'] ?? "";
                deptoCtrl.text = datos['depto'] ?? "";
                indicacionesCtrl.text = datos['indicaciones'] ?? "";
                telefonoCtrl.text = datos['telefono'] ?? "";
                selectedLocation = LatLng(
                  (datos['lat'] as num).toDouble(),
                  (datos['lng'] as num).toDouble(),
                );
                tieneDireccion = true;
                cargando = false;
              });
            },
          );
        }

        switch (_selectedIndex) {
          case 0:
            return _vistaHomePrincipal();
          case 1:
            return RecetasScreen(
              pacienteUuid: _userId ?? "",
              token: _userToken ?? "",
            );
          case 2:
            return ConsultasScreen(pacienteUuid: _userId ?? "");
          case 3:
            return PerfilScreen(userId: _userId ?? "");
          default:
            return _vistaHomePrincipal();
        }
      })(),



      // ---------------- NAV BAR CURVADA CON BLUR ----------------
      bottomNavigationBar: DocYaBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),

    );



  }
}
