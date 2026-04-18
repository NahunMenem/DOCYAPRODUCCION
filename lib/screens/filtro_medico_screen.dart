import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'complete_profile_screen.dart';
import 'solicitud_medico_screen.dart';

class FiltroMedicoScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacion;

  const FiltroMedicoScreen({
    super.key,
    required this.direccion,
    required this.ubicacion,
  });

  @override
  State<FiltroMedicoScreen> createState() => _FiltroMedicoScreenState();
}

class _FiltroMedicoScreenState extends State<FiltroMedicoScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, bool?> respuestas = {};

  final List<String> preguntas = [
    "¿Tiene dificultad grave para respirar?",
    "¿Tiene dolor intenso en el pecho?",
    "¿Tiene pérdida de conocimiento o convulsiones?",
    "¿Tiene sangrado abundante o que no se detiene?",
    "¿Tiene fiebre muy alta (más de 39.5 °C) con mal estado general?",
    "¿Se trata de un niño menor de 12 años con fiebre persistente o decaimiento?",
    "¿Tiene un accidente grave, fractura expuesta o quemadura extensa?",
  ];

  void _respuesta(String pregunta, bool valor) {
    setState(() => respuestas[pregunta] = valor);
    if (valor) _mostrarAlertaUrgencia();
  }

  void _mostrarAlertaUrgencia() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          "Urgencia detectada",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Esto puede ser una urgencia.\n\nLlamá al 911 o dirigite al hospital más cercano.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Entendido",
              style: TextStyle(color: Color(0xFF14B8A6)),
            ),
          ),
        ],
      ),
    );
  }

  bool _todasNo() {
    if (respuestas.length < preguntas.length) return false;
    return respuestas.values.every((v) => v == false);
  }

  Future<void> _continuarSolicitud() async {
    final prefs = await SharedPreferences.getInstance();
    final perfilCompleto = prefs.getBool("perfilCompleto") ?? false;

    if (!mounted) return;

    if (!perfilCompleto) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CompleteProfileScreen(forceProfile: true),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SolicitudMedicoScreen(
          direccion: widget.direccion,
          ubicacion: widget.ubicacion,
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsets? padding,
    double radius = 22,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : const Color(0xFF14B8A6).withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.18)
                    : const Color(0xFF14B8A6).withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _answerButton({
    required String label,
    required bool selected,
    required bool danger,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = danger ? Colors.redAccent : const Color(0xFF14B8A6);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: danger
                      ? const [Colors.redAccent, Color(0xFFFF6B6B)]
                      : const [Color(0xFF0EA896), Color(0xFF14B8A6)],
                )
              : null,
          color: selected
              ? null
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFF4F7F8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.14)
                : accent.withOpacity(isDark ? 0.20 : 0.10),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionCard(int index, String pregunta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final respuestaActual = respuestas[pregunta];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF14B8A6).withOpacity(
                      isDark ? 0.18 : 0.10,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        color: Color(0xFF14B8A6),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pregunta,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _answerButton(
                  label: "Sí",
                  selected: respuestaActual == true,
                  danger: true,
                  onTap: () => _respuesta(pregunta, true),
                ),
                const SizedBox(width: 12),
                _answerButton(
                  label: "No",
                  selected: respuestaActual == false,
                  danger: false,
                  onTap: () => _respuesta(pregunta, false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final continuarHabilitado = _todasNo();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendientes = preguntas.length - respuestas.length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF04151C) : const Color(0xFFF5F7F8),
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(
              left: -120,
              top: 70,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(20, 184, 166, 0.18),
                        Color.fromRGBO(20, 184, 166, 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -140,
              top: 220,
              child: IgnorePointer(
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(45, 212, 191, 0.14),
                        Color.fromRGBO(45, 212, 191, 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.90),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _glassCard(
                        radius: 28,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0EA896),
                                        Color(0xFF2DD4BF),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF14B8A6)
                                            .withOpacity(0.24),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF14B8A6)
                                              .withOpacity(
                                            isDark ? 0.16 : 0.10,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          "Filtro clínico",
                                          style: TextStyle(
                                            color: Color(0xFF14B8A6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Antes de continuar",
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          height: 1.05,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Respondé estas preguntas para descartar signos de urgencia y confirmar que la solicitud puede continuar dentro de la app.",
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.45,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : const Color(0xFFF7FBFB),
                                    border: Border.all(
                                      color: const Color(0xFF14B8A6)
                                          .withOpacity(isDark ? 0.18 : 0.10),
                                    ),
                                  ),
                                  child: Text(
                                    "Preguntas: ${preguntas.length}",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : const Color(0xFFF7FBFB),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B)
                                          .withOpacity(isDark ? 0.20 : 0.12),
                                    ),
                                  ),
                                  child: Text(
                                    pendientes > 0
                                        ? "Pendientes: $pendientes"
                                        : "Completado",
                                    style: TextStyle(
                                      color: pendientes > 0
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF14B8A6),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(
                        preguntas.length,
                        (index) => _questionCard(index, preguntas[index]),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: continuarHabilitado
                      ? SafeArea(
                          key: const ValueKey("continuar"),
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0EA896),
                                    Color(0xFF14B8A6),
                                    Color(0xFF2DD4BF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF14B8A6)
                                        .withOpacity(0.24),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _continuarSolicitud,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "Continuar solicitud",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
