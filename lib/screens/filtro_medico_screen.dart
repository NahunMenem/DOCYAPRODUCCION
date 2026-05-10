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

class _QuestionStyle {
  final IconData icon;
  final Color color;

  const _QuestionStyle(this.icon, this.color);
}

class _FiltroMedicoScreenState extends State<FiltroMedicoScreen>
    with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF14B8A6);
  static const Color _tealLight = Color(0xFF2DD4BF);
  static const Color _darkBg = Color(0xFF03161D);
  static const Color _red = Color(0xFFE74460);

  final Map<String, bool?> respuestas = {};

  final List<String> preguntas = [
    "¿Tenés dificultad grave para respirar?",
    "¿Tenés dolor intenso en el pecho?",
    "¿Tenés pérdida de conocimiento o convulsiones?",
    "¿Tenés sangrado abundante o que no se detiene?",
    "¿Tenés fiebre muy alta (más de 39.5 °C) con mal estado general?",
    "¿Se trata de un niño menor de 12 años con fiebre persistente o decaimiento?",
    "¿Tuviste un accidente grave, fractura expuesta o quemadura extensa?",
  ];

  final List<_QuestionStyle> _questionStyles = const [
    _QuestionStyle(Icons.air_rounded, Color(0xFF38D7D2)),
    _QuestionStyle(Icons.favorite_rounded, Color(0xFFFF4F70)),
    _QuestionStyle(Icons.psychology_rounded, Color(0xFFA78BFA)),
    _QuestionStyle(Icons.water_drop_rounded, Color(0xFFFF344E)),
    _QuestionStyle(Icons.device_thermostat_rounded, Color(0xFFFF9B45)),
    _QuestionStyle(Icons.child_care_rounded, Color(0xFF2DD4BF)),
    _QuestionStyle(Icons.healing_rounded, Color(0xFFFFB84D)),
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
          "Esto puede ser una urgencia.\n\nLlamá al 107 o al 911, o dirigite al hospital más cercano.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Entendido",
              style: TextStyle(color: _teal),
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
    bool strong = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? (strong ? const Color(0xFF082832) : const Color(0xFF08212A))
            .withValues(alpha: strong ? 0.84 : 0.76)
        : Colors.white.withValues(alpha: strong ? 0.98 : 0.94);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : _teal.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : const Color(0xFF0F766E).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _topBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _squareButton(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Image.asset(
                isDark ? "assets/logoblanco.png" : "assets/logonegro.png",
                height: 54,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? _teal.withValues(alpha: 0.22)
                    : const Color(0xFFE4EEEE),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Menos de",
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 9,
                        height: 1,
                      ),
                    ),
                    Text(
                      "30 segundos",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE6F0F0),
            ),
          ),
          child: Icon(icon, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _heroCard(bool isDark) {
    final answered = respuestas.length;

    return _glassCard(
      radius: 28,
      strong: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF0E8E83), Color(0xFF064D52)]
                        : const [Color(0xFFE1FFFB), Color(0xFF8CF0E4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: isDark ? 0.20 : 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: isDark ? Colors.white : const Color(0xFF08776E),
                  size: 58,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: isDark ? 0.16 : 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        "FILTRO CLÍNICO",
                        style: TextStyle(
                          color: _tealLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Verifiquemos que no sea una urgencia",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF102027),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Estas preguntas nos ayudan a detectar situaciones que requieren atención inmediata.",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.035)
                  : const Color(0xFFF7FBFB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "$answered",
                        style: const TextStyle(color: _tealLight),
                      ),
                      TextSpan(
                        text: " de ${preguntas.length} ",
                      ),
                      const TextSpan(text: "preguntas"),
                    ],
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF102027),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: _progressSegments(answered, isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressSegments(int answered, bool isDark) {
    return Row(
      children: List.generate(preguntas.length, (index) {
        final done = index < answered;
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: index == preguntas.length - 1 ? 0 : 7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 8,
              decoration: BoxDecoration(
                color: done
                    ? _tealLight
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFD7E5E5)),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _questionItem(int index, String pregunta) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final respuestaActual = respuestas[pregunta];
    final answered = respuestaActual != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _timelineMarker(
              isDark: isDark,
              answered: answered,
              first: index == 0,
              last: index == preguntas.length - 1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _questionCard(index, pregunta, isDark)),
        ],
      ),
    );
  }

  Widget _timelineMarker({
    required bool isDark,
    required bool answered,
    required bool first,
    required bool last,
  }) {
    final lineColor =
        isDark ? Colors.white.withValues(alpha: 0.11) : const Color(0xFFD4E5E5);

    return SizedBox(
      width: 28,
      height: 96,
      child: Column(
        children: [
          Container(
            width: 2,
            height: 34,
            color: first ? Colors.transparent : lineColor,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: answered ? _tealLight : Colors.transparent,
              border: Border.all(
                color: answered ? _tealLight : lineColor,
                width: 2,
              ),
            ),
            child: answered
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
                : null,
          ),
          Container(
            width: 2,
            height: 34,
            color: last ? Colors.transparent : lineColor,
          ),
        ],
      ),
    );
  }

  Widget _questionCard(int index, String pregunta, bool isDark) {
    final style = _questionStyles[index];
    final respuestaActual = respuestas[pregunta];

    return _glassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final questionHeader = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFF0F7F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(style.icon, color: style.color, size: 34),
              ),
              const SizedBox(width: 12),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_tealLight, Color(0xFF0C948B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pregunta,
                  style: TextStyle(
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w900,
                    height: 1.22,
                    color: isDark ? Colors.white : const Color(0xFF102027),
                  ),
                ),
              ),
            ],
          );

          final buttons = Row(
            children: [
              _answerButton(
                label: "No",
                icon: Icons.check_circle_outline_rounded,
                selected: respuestaActual == false,
                danger: false,
                onTap: () => _respuesta(pregunta, false),
              ),
              const SizedBox(width: 10),
              _answerButton(
                label: "Sí",
                icon: Icons.warning_amber_rounded,
                selected: respuestaActual == true,
                danger: true,
                onTap: () => _respuesta(pregunta, true),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                questionHeader,
                const SizedBox(height: 14),
                buttons,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: questionHeader),
              const SizedBox(width: 16),
              SizedBox(width: 250, child: buttons),
            ],
          );
        },
      ),
    );
  }

  Widget _answerButton({
    required String label,
    required IconData icon,
    required bool selected,
    required bool danger,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = danger ? _red : _teal;
    final selectedGradient = danger
        ? const [Color(0xFFB8324A), Color(0xFFE74460)]
        : const [Color(0xFF087D78), Color(0xFF11B6A5)];

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? selectedGradient
                : [
                    accent.withValues(alpha: isDark ? 0.22 : 0.10),
                    accent.withValues(alpha: isDark ? 0.16 : 0.08),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withValues(alpha: selected ? 0.92 : 0.55),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (danger
                            ? (isDark ? const Color(0xFFFFC3CD) : _red)
                            : (isDark ? const Color(0xFFB9FFF7) : _teal)),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : (danger
                          ? (isDark ? const Color(0xFFFFC3CD) : _red)
                          : (isDark ? const Color(0xFFB9FFF7) : _teal)),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _safetyCards(bool isDark) {
    return Column(
      children: [
        _glassCard(
          radius: 22,
          strong: true,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF91FFF2), Color(0xFF0D958C)]
                        : const [Color(0xFFDFFFFA), Color(0xFF65E4D7)],
                  ),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: isDark ? _darkBg : const Color(0xFF08776E),
                  size: 46,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Tu seguridad es nuestra prioridad",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF102027),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const Icon(Icons.verified_rounded, color: _tealLight),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Si respondés “Sí” a alguna pregunta, te damos las indicaciones correspondientes antes de continuar.",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _glassCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _red.withValues(alpha: isDark ? 0.72 : 0.12),
                ),
                child: Icon(
                  Icons.phone_in_talk_rounded,
                  color: isDark ? Colors.white : _red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "En caso de emergencia, llamá al 107 o 911",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF102027),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Este filtro no reemplaza una evaluación médica profesional.",
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footerBenefits(bool isDark) {
    final benefits = [
      (Icons.health_and_safety_outlined, "Seguro y confiable"),
      (Icons.lock_outline_rounded, "Tus datos están protegidos"),
      (Icons.speed_rounded, "Rápido y simple"),
      (Icons.auto_awesome_rounded, "Tecnología médica"),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: benefits.map((item) {
        return SizedBox(
          width: 145,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, color: _tealLight, size: 27),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.$2,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final continuarHabilitado = _todasNo();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _darkBg : const Color(0xFFF4F8F8),
      body: Stack(
        children: [
          Positioned.fill(child: _background(isDark)),
          SafeArea(
            child: Column(
              children: [
                _topBar(isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 112),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _heroCard(isDark),
                      const SizedBox(height: 20),
                      ...List.generate(
                        preguntas.length,
                        (index) => _questionItem(index, preguntas[index]),
                      ),
                      const SizedBox(height: 18),
                      _safetyCards(isDark),
                      const SizedBox(height: 24),
                      _footerBenefits(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
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
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              (isDark ? _darkBg : const Color(0xFFF4F8F8))
                                  .withValues(alpha: 0.0),
                              isDark ? _darkBg : const Color(0xFFF4F8F8),
                            ],
                          ),
                        ),
                        child: _continueButton(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _background(bool isDark) {
    if (!isDark) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FFFF), Color(0xFFEFF7F7)],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF021116), Color(0xFF06252F), Color(0xFF021116)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -120,
            top: 60,
            child: _glow(const Color(0xFF14B8A6), 280, 0.18),
          ),
          Positioned(
            right: -170,
            top: 260,
            child: _glow(const Color(0xFF2DD4BF), 360, 0.12),
          ),
          Positioned(
            left: 60,
            bottom: -130,
            child: _glow(const Color(0xFF14B8A6), 300, 0.09),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size, double opacity) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.45),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _continueButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA896), _teal, _tealLight],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.24),
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
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  "Continuar solicitud",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
