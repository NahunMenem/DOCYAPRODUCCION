import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../globals.dart';
import '../services/auth_service.dart';
import '../widgets/docya_snackbar.dart';
import 'terminos_screen.dart';
import 'complete_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _name = TextEditingController();
  final _dni = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _pais;
  String? _provincia;
  String? _localidad;
  DateTime? _fechaNacimiento;
  String? _sexo;
  bool _aceptaCondiciones = false;
  bool _loading = false;
  bool _loadingGoogle = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  //--------------------------------------------------------------------
  // PROVINCIAS
  //--------------------------------------------------------------------
  final List<String> _provincias = [
    "Buenos Aires",
    "Ciudad Autónoma de Buenos Aires",
    "Catamarca",
    "Chaco",
    "Chubut",
    "Córdoba",
    "Corrientes",
    "Entre Ríos",
    "Formosa",
    "Jujuy",
    "La Pampa",
    "La Rioja",
    "Mendoza",
    "Misiones",
    "Neuquén",
    "Río Negro",
    "Salta",
    "San Juan",
    "San Luis",
    "Santa Cruz",
    "Santa Fe",
    "Santiago del Estero",
    "Tierra del Fuego",
    "Tucumán"
  ];

  List<String> _localidades = [];

  //--------------------------------------------------------------------
  // CARGA LOCALIDADES
  //--------------------------------------------------------------------
  Future<void> _cargarLocalidades(String provincia) async {
    if (provincia == "Ciudad Autónoma de Buenos Aires") {
      setState(() {
        _localidades = [
          "Comuna 1", "Comuna 2", "Comuna 3", "Comuna 4", "Comuna 5",
          "Comuna 6", "Comuna 7", "Comuna 8", "Comuna 9", "Comuna 10",
          "Comuna 11", "Comuna 12", "Comuna 13", "Comuna 14", "Comuna 15",
        ];
        _localidad = null;
      });
      return;
    }

    try {
      final encoded = Uri.encodeComponent(provincia);
      final url =
          "https://docya-railway-production.up.railway.app/localidades/$encoded";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _localidades = List<String>.from(data["localidades"]);
          _localidad = null;
        });
      } else {
        setState(() => _localidades = []);
      }
    } catch (e) {
      setState(() => _localidades = []);
    }
  }

  //--------------------------------------------------------------------
  // GOOGLE REGISTER / LOGIN
  //--------------------------------------------------------------------
  Future<void> _submitGoogle() async {
    setState(() => _loadingGoogle = true);
    final loginData = await _auth.loginWithGoogle();
    setState(() => _loadingGoogle = false);

    if (!mounted || loginData == null) return;

    if (loginData["ok"] != true) {
      DocYaSnackbar.show(
        context,
        title: "Google no disponible",
        message: loginData["detail"] ?? "No se pudo continuar con Google.",
        type: SnackType.error,
      );
      return;
    }

    final token = loginData["access_token"] ?? "";
    final id = loginData["user_id"]?.toString() ?? "";
    final nombre = loginData["full_name"] ?? "Usuario";
    final email = loginData["email"]?.toString() ?? "";
    final perfilCompleto = loginData["perfil_completo"] == true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
    await prefs.setString("nombreUsuario", nombre);
    await prefs.setString("userId", id);
    await prefs.setBool("perfilCompleto", perfilCompleto);
    pacienteUuidGlobal = id;
    pacienteEmailGlobal = email;

    // Registrar FCM token
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await http.post(
          Uri.parse(
              "https://docya-railway-production.up.railway.app/users/$id/fcm_token"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"fcm_token": fcmToken}),
        );
      }
    } catch (_) {}

    if (!mounted) return;

    if (!perfilCompleto) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CompleteProfileScreen(forceProfile: true),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, "/home");

    DocYaSnackbar.show(
      context,
      title: "Bienvenido",
      message: "Ingresaste con Google correctamente.",
      type: SnackType.success,
    );
  }

  //--------------------------------------------------------------------
  // SUBMIT FORMULARIO
  //--------------------------------------------------------------------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pais == null) {
      setState(() => _error = "Seleccioná tu país");
      return;
    }

    if (_pais == "Argentina" && (_provincia == null || _localidad == null)) {
      setState(() => _error = "Seleccioná provincia y localidad");
      return;
    }

    if (_fechaNacimiento == null) {
      setState(() => _error = "Seleccioná tu fecha de nacimiento");
      return;
    }

    if (_sexo == null) {
      setState(() => _error = "Seleccioná tu sexo");
      return;
    }

    if (!_aceptaCondiciones) {
      setState(() => _error = "Debés aceptar los Términos y Condiciones");
      return;
    }

    if (_password.text.trim() != _confirm.text.trim()) {
      setState(() => _error = "Las contraseñas no coinciden");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _auth.register(
      _name.text.trim(),
      _email.text.trim(),
      _password.text.trim(),
      dni: _dni.text.trim(),
      telefono: _phone.text.trim(),
      pais: _pais!,
      provincia: _pais == "Argentina" ? _provincia : null,
      localidad: _pais == "Argentina" ? _localidad : null,
      fechaNacimiento: _fechaNacimiento!.toIso8601String(),
      sexo: _sexo!,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result["ok"] == true) {
      Navigator.pop(context);
      DocYaSnackbar.show(
        context,
        title: "Registro exitoso",
        message: "Revisá tu correo para activar tu cuenta.",
        type: SnackType.success,
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "Error",
        message: result["detail"] ?? "No se pudo registrar.",
        type: SnackType.error,
      );
    }
  }

  //--------------------------------------------------------------------
  // INPUT STYLE
  //--------------------------------------------------------------------
  InputDecoration _input(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? Colors.white38 : Colors.black38,
        size: 20,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon,
    bool isDark, {
    bool obs = false,
    bool isPassword = false,
    VoidCallback? onToggleObs,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        obscureText: obs,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 15,
        ),
        decoration: _input(label, icon, isDark).copyWith(
          suffixIcon: isPassword
              ? IconButton(
                  onPressed: onToggleObs,
                  icon: Icon(
                    obs
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: isDark ? Colors.white38 : Colors.black38,
                    size: 20,
                  ),
                )
              : null,
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      ),
    );
  }

  //--------------------------------------------------------------------
  // BUILD
  //--------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final double paddingSide = size.width * 0.06;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF04151C) : const Color(0xFFF0F4F8),
      body: Container(
        width: size.width,
        height: size.height,
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF071E26),
                    Color(0xFF04151C),
                    Color(0xFF051218),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              )
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8F4F8), Color(0xFFF0F4F8)],
                ),
              ),
        child: Stack(
          children: [
            // Orbe superior derecho
            Positioned(
              right: -120,
              top: -80,
              child: IgnorePointer(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color.fromRGBO(20, 184, 166, 0.16)
                            : const Color.fromRGBO(20, 184, 166, 0.09),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Orbe inferior izquierdo
            Positioned(
              left: -100,
              bottom: 60,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color.fromRGBO(58, 134, 255, 0.12)
                            : const Color.fromRGBO(58, 134, 255, 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: paddingSide, vertical: 24),
                child: Column(
                  children: [
                    // LOGO
                    Image.network(
                      isDark
                          ? "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logoblanco_1_qdlnog.png"
                          : "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logo_1_svfdye.png",
                      height: size.width * 0.22,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Creá tu cuenta gratis",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Atención médica a domicilio en minutos",
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // -----------------------------------------------
                    // CARD GOOGLE (DESTACADO)
                    // -----------------------------------------------
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.white.withOpacity(0.80),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.10)
                                  : Colors.black.withOpacity(0.07),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Badge "Recomendado"
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF14B8A6)
                                        .withOpacity(0.30),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 14,
                                      color: Color(0xFF14B8A6),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "La forma más rápida",
                                      style: TextStyle(
                                        color: Color(0xFF14B8A6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              Text(
                                "Registrate con Google",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Sin contraseña, en un solo tap",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  fontSize: 12.5,
                                ),
                              ),

                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: (_loading || _loadingGoogle)
                                      ? null
                                      : _submitGoogle,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.15)
                                            : Colors.black.withOpacity(0.12),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(isDark ? 0.2 : 0.06),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: _loadingGoogle
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF14B8A6),
                                                strokeWidth: 2.4,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Image.asset(
                                                  "assets/google_logo.png",
                                                  width: 22,
                                                  height: 22,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  "Continuar con Google",
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A1A2E),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DIVISOR "o registrate con email"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? Colors.white.withOpacity(0.12)
                                : Colors.black.withOpacity(0.10),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            "o registrate con email",
                            style: TextStyle(
                              color:
                                  isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark
                                ? Colors.white.withOpacity(0.12)
                                : Colors.black.withOpacity(0.10),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // -----------------------------------------------
                    // CARD FORMULARIO
                    // -----------------------------------------------
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.07)
                                : Colors.white.withOpacity(0.80),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.10)
                                  : Colors.black.withOpacity(0.07),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.06),
                                blurRadius: 30,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Tus datos",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Completá el formulario para crear tu cuenta",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                _field(_name, "Nombre y apellido",
                                    Icons.person_outline_rounded, isDark),
                                _field(_dni, "DNI / Pasaporte",
                                    Icons.badge_outlined, isDark),
                                _field(_phone, "Teléfono",
                                    Icons.phone_outlined, isDark),
                                _field(_email, "Correo electrónico",
                                    Icons.email_outlined, isDark),
                                _field(
                                  _password,
                                  "Contraseña",
                                  Icons.lock_outline_rounded,
                                  isDark,
                                  obs: _obscurePassword,
                                  isPassword: true,
                                  onToggleObs: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                _field(
                                  _confirm,
                                  "Confirmar contraseña",
                                  Icons.lock_outline_rounded,
                                  isDark,
                                  obs: _obscureConfirm,
                                  isPassword: true,
                                  onToggleObs: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),

                                // FECHA NACIMIENTO
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime(now.year - 25),
                                        firstDate: DateTime(1900),
                                        lastDate: now,
                                        builder: (context, child) {
                                          return Theme(
                                            data: ThemeData(
                                              colorScheme: ColorScheme.light(
                                                primary:
                                                    const Color(0xFF14B8A6),
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black87,
                                              ),
                                              dialogBackgroundColor:
                                                  Colors.white,
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(
                                            () => _fechaNacimiento = picked);
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: _input(
                                          "Fecha de nacimiento",
                                          Icons.cake_outlined,
                                          isDark),
                                      child: Text(
                                        _fechaNacimiento == null
                                            ? "Seleccionar fecha"
                                            : "${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}",
                                        style: TextStyle(
                                          color: _fechaNacimiento == null
                                              ? (isDark
                                                  ? Colors.white38
                                                  : Colors.black38)
                                              : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A)),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // SEXO
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: DropdownButtonFormField<String>(
                                    value: _sexo,
                                    decoration: _input(
                                        "Sexo", Icons.people_outline, isDark),
                                    dropdownColor: isDark
                                        ? const Color(0xFF1A2E35)
                                        : Colors.white,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 15,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: "Masculino",
                                          child: Text("Masculino")),
                                      DropdownMenuItem(
                                          value: "Femenino",
                                          child: Text("Femenino")),
                                      DropdownMenuItem(
                                          value: "Otro",
                                          child:
                                              Text("Otro / Prefiero no decir")),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _sexo = v),
                                    validator: (v) =>
                                        v == null ? "Requerido" : null,
                                  ),
                                ),

                                // PAÍS
                                DropdownButtonFormField<String>(
                                  decoration:
                                      _input("País", Icons.public_outlined, isDark),
                                  dropdownColor: isDark
                                      ? const Color(0xFF1A2E35)
                                      : Colors.white,
                                  isExpanded: true,
                                  value: _pais,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontSize: 15,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: "Argentina",
                                      child: Text("Argentina"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Extranjero",
                                      child: Text("Extranjero / Turista"),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      _pais = v;
                                      _provincia = null;
                                      _localidad = null;
                                      _localidades = [];
                                    });
                                  },
                                ),

                                const SizedBox(height: 14),

                                if (_pais == "Argentina") ...[
                                  DropdownButtonFormField<String>(
                                    decoration: _input(
                                        "Provincia", Icons.map_outlined, isDark),
                                    dropdownColor: isDark
                                        ? const Color(0xFF1A2E35)
                                        : Colors.white,
                                    value: _provincia,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 15,
                                    ),
                                    items: _provincias
                                        .map((p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(p),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() {
                                        _provincia = v;
                                        _localidad = null;
                                        _localidades = [];
                                      });
                                      if (v != null) _cargarLocalidades(v);
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    decoration: _input("Localidad",
                                        Icons.location_city_outlined, isDark),
                                    dropdownColor: isDark
                                        ? const Color(0xFF1A2E35)
                                        : Colors.white,
                                    value: _localidad,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 15,
                                    ),
                                    items: _localidades
                                        .map((l) => DropdownMenuItem(
                                              value: l,
                                              child: Text(l),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _localidad = v),
                                  ),
                                ],

                                if (_pais == "Extranjero") ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14B8A6)
                                          .withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF14B8A6)
                                            .withOpacity(0.20),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: Color(0xFF14B8A6),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Si sos turista, solo completá tus datos. En la consulta elegís tu ubicación exacta.",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // TÉRMINOS
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.04)
                                        : Colors.black.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.06),
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: _aceptaCondiciones,
                                    activeColor: const Color(0xFF14B8A6),
                                    checkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Wrap(
                                      children: [
                                        Text(
                                          "Acepto los ",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const TerminosScreen()),
                                          ),
                                          child: const Text(
                                            "Términos y Condiciones",
                                            style: TextStyle(
                                              color: Color(0xFF14B8A6),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onChanged: (v) => setState(
                                        () => _aceptaCondiciones = v!),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444)
                                          .withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFEF4444)
                                            .withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 22),

                                // BOTON CREAR CUENTA
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed:
                                        (_loading || _loadingGoogle) ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: (_loading || _loadingGoogle)
                                            ? null
                                            : const LinearGradient(
                                                colors: [
                                                  Color(0xFF2DD4BF),
                                                  Color(0xFF0D9488)
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                        color: (_loading || _loadingGoogle)
                                            ? (isDark
                                                ? Colors.white12
                                                : Colors.black12)
                                            : null,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        boxShadow: (_loading || _loadingGoogle)
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: const Color(0xFF14B8A6)
                                                      .withOpacity(0.38),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: _loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.4,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .person_add_alt_1_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Crear cuenta",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // YA TENGO CUENTA
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "¿Ya tenés cuenta?",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 4),
                                        ),
                                        child: const Text(
                                          "Iniciá sesión",
                                          style: TextStyle(
                                            color: Color(0xFF14B8A6),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
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
