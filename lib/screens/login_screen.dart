// lib/screens/login_screen.dart

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';

import '../globals.dart';
import '../services/auth_service.dart';
import '../services/live_activity_service.dart';
import '../widgets/docya_snackbar.dart';
import 'buscando_medico_screen.dart';
import 'MedicoEnCaminoScreen.dart';
import 'EnfermeroEnCaminoScreen.dart';
import 'consulta_en_curso_screen.dart';
import 'complete_profile_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailOrDni = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePassword = true;
  final _auth = AuthService();

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // SAVE LOCAL
  // ---------------------------------------------------------------

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
  }

  Future<void> _saveUser(String nombre, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("nombreUsuario", nombre);
    await prefs.setString("userId", id);
  }

  Future<void> _savePerfilCompleto(bool completo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("perfilCompleto", completo);
  }

  Future<void> _registrarFcm(String id) async {
    String? apns = await FirebaseMessaging.instance.getAPNSToken();
    int retries = 0;
    while (apns == null && retries < 5) {
      await Future.delayed(const Duration(seconds: 1));
      apns = await FirebaseMessaging.instance.getAPNSToken();
      retries++;
    }

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await http.post(
        Uri.parse(
            "https://docya-railway-production.up.railway.app/users/$id/fcm_token"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"fcm_token": fcmToken}),
      );
    }
  }

  Future<void> _postLoginSuccess(Map<String, dynamic> loginData) async {
    final token = loginData["access_token"] ?? "";
    final id = loginData["user_id"]?.toString() ?? "";
    final nombre = loginData["full_name"] ?? "Usuario";
    final email = loginData["email"]?.toString() ?? _emailOrDni.text.trim();
    final perfilCompleto = loginData["perfil_completo"] == true;

    await _saveToken(token);
    await _saveUser(nombre, id);
    await _savePerfilCompleto(perfilCompleto);
    pacienteUuidGlobal = id;
    pacienteEmailGlobal = email;

    await _registrarFcm(id);

    if (!mounted) return;

    final restauroConsulta = await _restaurarConsultaActiva();
    if (!mounted || restauroConsulta) return;

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
  }

  Future<bool> _restaurarConsultaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    final consultaIdStr = prefs.getString("consulta_activa_id");

    if (consultaIdStr == null) return false;

    try {
      final consultaId = int.parse(consultaIdStr);
      final r = await http.get(Uri.parse("$API_URL/consultas/$consultaId"));

      if (r.statusCode != 200) {
        await prefs.remove("consulta_activa_id");
        return false;
      }

      final data = jsonDecode(r.body);
      final estado = data["estado"];
      final tipo = data["tipo"] ?? "medico";

      if (!mounted) return true;

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
              pacienteUuid: data["paciente_uuid"]?.toString() ?? "",
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
                    pacienteUuid: data["paciente_uuid"]?.toString() ?? "",
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
                    pacienteUuid: data["paciente_uuid"]?.toString() ?? "",
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
              pacienteUuid: data["paciente_uuid"]?.toString() ?? "",
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

      await prefs.remove("consulta_activa_id");
      return false;
    } catch (_) {
      await prefs.remove("consulta_activa_id");
      return false;
    }
  }

  // ---------------------------------------------------------------
  // RECUPERAR CONTRASEÑA
  // ---------------------------------------------------------------

  Future<void> _recuperarContrasena() async {
    final identificadorController = TextEditingController();
    bool cargando = false;

    await showDialog(
      context: context,
      barrierDismissible: !cargando,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            backgroundColor: const Color(0xFF1A2E35),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Recuperar contraseña",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            content: TextField(
              controller: identificadorController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ingresá tu email o DNI",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: cargando ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar",
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: cargando
                    ? null
                    : () async {
                        setStateDialog(() => cargando = true);
                        try {
                          final res = await http.post(
                            Uri.parse(
                                "https://docya-railway-production.up.railway.app/auth/forgot_password_paciente"),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode({
                              "identificador":
                                  identificadorController.text.trim()
                            }),
                          );

                          Navigator.pop(ctx);

                          if (res.statusCode == 200) {
                            final data = jsonDecode(res.body);
                            DocYaSnackbar.show(
                              context,
                              title: "Email enviado",
                              message: data["message"] ??
                                  "Te enviamos un correo con instrucciones.",
                              type: SnackType.success,
                            );
                          } else {
                            final data = jsonDecode(res.body);
                            DocYaSnackbar.show(
                              context,
                              title: "Error",
                              message: data["detail"] ??
                                  "No se encontró ningún usuario con esos datos.",
                              type: SnackType.error,
                            );
                          }
                        } catch (e) {
                          Navigator.pop(ctx);
                          DocYaSnackbar.show(
                            context,
                            title: "Error interno",
                            message:
                                "Hubo un problema al conectar con el servidor.",
                            type: SnackType.error,
                          );
                        }
                      },
                child: cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Enviar",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    debugPrint("Login paciente: iniciando request");

    final loginData =
        await _auth.login(_emailOrDni.text.trim(), _password.text.trim());

    setState(() => _loading = false);

    if (loginData == null || loginData["ok"] != true) {
      DocYaSnackbar.show(
        context,
        title: "Datos incorrectos",
        message: loginData?["detail"] ??
            "No se pudo iniciar sesión. Verificá tus datos o intentá nuevamente en unos segundos.",
        type: SnackType.error,
      );
      return;
    }

    try {
      await _postLoginSuccess(loginData);

      DocYaSnackbar.show(
        context,
        title: "Bienvenido",
        message:
            "Hola ${loginData["full_name"] ?? "Usuario"}, ingresaste con éxito.",
        type: SnackType.success,
      );
    } catch (e) {
      print("ERROR LOGIN: $e");
      DocYaSnackbar.show(
        context,
        title: "Error interno",
        message: "No se pudieron guardar los datos.",
        type: SnackType.error,
      );
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _loading = true);
    final loginData = await _auth.loginWithGoogle();
    setState(() => _loading = false);

    if (!mounted || loginData == null) return;

    if (loginData["ok"] != true) {
      DocYaSnackbar.show(
        context,
        title: "Google no disponible",
        message: loginData["detail"] ?? "No se pudo iniciar sesión con Google.",
        type: SnackType.error,
      );
      return;
    }

    try {
      await _postLoginSuccess(loginData);
      DocYaSnackbar.show(
        context,
        title: "Bienvenido",
        message: "Ingresaste con Google correctamente.",
        type: SnackType.success,
      );
    } catch (_) {
      DocYaSnackbar.show(
        context,
        title: "Error",
        message: "No se pudo completar el ingreso con Google.",
        type: SnackType.error,
      );
    }
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const kPrimary = Color(0xFF14B8A6);
    const kPrimaryDark = Color(0xFF0D9488);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final double logoSize = size.width * 0.28;
    final double paddingSide = size.width * 0.06;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF04151C) : const Color(0xFFF0F4F8),
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
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color.fromRGBO(20, 184, 166, 0.18)
                            : const Color.fromRGBO(20, 184, 166, 0.10),
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
              bottom: 80,
              child: IgnorePointer(
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color.fromRGBO(58, 134, 255, 0.14)
                            : const Color.fromRGBO(58, 134, 255, 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Orbe central izquierdo
            Positioned(
              left: -160,
              top: size.height * 0.3,
              child: IgnorePointer(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isDark
                            ? const Color.fromRGBO(0, 210, 255, 0.12)
                            : const Color.fromRGBO(0, 210, 255, 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                SizedBox(height: size.height * 0.13),

                // LOGO + TAGLINE
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        Image.network(
                          isDark
                              ? "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logoblanco_1_qdlnog.png"
                              : "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logo_1_svfdye.png",
                          height: logoSize,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Atención médica a tu alcance",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withOpacity(0.45)
                                : Colors.black.withOpacity(0.38),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: size.height * 0.045),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: paddingSide),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          _glassForm(kPrimary, kPrimaryDark, isDark),
                          SizedBox(height: size.height * 0.025),

                          // SOPORTE WHATSAPP
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.07),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "¿Necesitás ayuda?",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => launchUrl(
                                    Uri.parse("https://wa.me/5491168700607"),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14B8A6)
                                          .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFF14B8A6)
                                            .withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.support_agent_rounded,
                                          size: 15,
                                          color: Color(0xFF14B8A6),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Soporte",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // FORM GLASS
  // ---------------------------------------------------------------

  Widget _glassForm(Color kPrimary, Color kPrimaryDark, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
                // TITULO
                Text(
                  "Iniciá sesión",
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Ingresá con tu cuenta DocYa",
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),

                // CAMPO EMAIL / DNI
                TextFormField(
                  controller: _emailOrDni,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                  ),
                  decoration: _inputStyle("Email o DNI", Icons.person_outline_rounded, isDark),
                  validator: (v) =>
                      v == null || v.isEmpty ? "Ingresá tu email o DNI" : null,
                ),
                const SizedBox(height: 14),

                // CAMPO CONTRASEÑA
                TextFormField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                  ),
                  decoration: _inputStyle(
                    "Contraseña",
                    Icons.lock_outline_rounded,
                    isDark,
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? "Mínimo 6 caracteres" : null,
                ),

                // OLVIDASTE CONTRASEÑA
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _recuperarContrasena,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                    ),
                    child: Text(
                      "¿Olvidaste tu contraseña?",
                      style: TextStyle(
                        color: kPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // BOTON INGRESAR
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _loading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: _loading
                            ? (isDark
                                ? Colors.white12
                                : Colors.black12)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _loading
                            ? []
                            : [
                                BoxShadow(
                                  color: kPrimary.withOpacity(0.38),
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
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Ingresar",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // DIVISOR "o continua con"
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        "o continua con",
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
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

                const SizedBox(height: 14),

                // BOTON GOOGLE
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _submitGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.12),
                        width: 1,
                      ),
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.white.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/google_logo.png",
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Continuar con Google",
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // REGISTRO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tenés cuenta?",
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                      ),
                      child: const Text(
                        "Registrate",
                        style: TextStyle(
                          color: Color(0xFF14B8A6),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // INPUT STYLE
  // ---------------------------------------------------------------

  InputDecoration _inputStyle(String label, IconData icon, bool isDark) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
}
