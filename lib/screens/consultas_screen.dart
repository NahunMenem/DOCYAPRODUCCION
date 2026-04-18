import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ConsultasScreen extends StatefulWidget {
  final String pacienteUuid;

  const ConsultasScreen({super.key, required this.pacienteUuid});

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen> {
  List<dynamic> consultas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoriaClinica();
  }

  Future<void> _fetchHistoriaClinica() async {
    final url =
        "https://docya-railway-production.up.railway.app/pacientes/${widget.pacienteUuid}/historia_clinica";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          consultas = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error ${response.statusCode}: no se pudo cargar la historia clínica",
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error cargando historia clínica: $e")),
      );
    }
  }

  Color _estadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case "finalizada":
        return const Color(0xFF14B8A6);
      case "cancelada":
        return Colors.redAccent;
      case "aceptada":
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _estadoIcono(String estado) {
    switch (estado.toLowerCase()) {
      case "finalizada":
        return PhosphorIconsRegular.checkCircle;
      case "cancelada":
        return PhosphorIconsRegular.xCircle;
      case "aceptada":
        return PhosphorIconsRegular.handshake;
      default:
        return PhosphorIconsRegular.clock;
    }
  }

  String _estadoLabel(String estado) {
    if (estado.trim().isEmpty) return "Pendiente";
    return estado[0].toUpperCase() + estado.substring(1).toLowerCase();
  }

  String _soloFecha(dynamic valor) {
    if (valor == null) return "-";
    final s = valor.toString();
    // ISO 8601: "2024-03-15T10:30:00" → "2024-03-15"
    // Si contiene T o espacio, cortar ahí
    final tIdx = s.indexOf('T');
    if (tIdx > 0) return s.substring(0, tIdx);
    final spIdx = s.indexOf(' ');
    if (spIdx > 0) return s.substring(0, spIdx);
    return s;
  }

  Map<String, dynamic>? _parseHistoria(dynamic raw) {
    if (raw == null) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return null;
  }

  Widget _glassCard(
    BuildContext context, {
    required Widget child,
    EdgeInsets? padding,
    double radius = 24,
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

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF14B8A6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            height: 1.35,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color accent = const Color(0xFF14B8A6),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(isDark ? 0.18 : 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            "$label: $value",
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clinicalBlock(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.16 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF14B8A6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF14B8A6),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(BuildContext context, dynamic consulta, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estado = (consulta['estado'] ?? "").toString();
    final colorEstado = _estadoColor(estado);
    final historia = _parseHistoria(consulta['historia_clinica']);
    final profesional =
        consulta['medico']?.toString().trim().isNotEmpty == true
            ? consulta['medico'].toString().trim()
            : "Profesional no asignado";
    final signos = historia?['signos_vitales'];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorEstado.withOpacity(0.95),
                        colorEstado.withOpacity(0.72),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorEstado.withOpacity(0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _estadoIcono(estado),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (index != consultas.length - 1)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorEstado.withOpacity(0.35),
                            isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _glassCard(
                context,
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
                              Text(
                                "Consulta #${consulta['consulta_id'] ?? '-'}",
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profesional,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _estadoLabel(estado),
                            style: GoogleFonts.manrope(
                              color: colorEstado,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _infoChip(
                          context,
                          icon: PhosphorIconsRegular.calendarBlank,
                          label: "Fecha",
                          value: _soloFecha(consulta['fecha_consulta']),
                        ),
                        if (consulta['fecha_nota'] != null)
                          _infoChip(
                            context,
                            icon: PhosphorIconsRegular.notePencil,
                            label: "Nota clínica",
                            value: _soloFecha(consulta['fecha_nota']),
                            accent: const Color(0xFF0EA5E9),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(
                      context,
                      "Motivo de consulta",
                      "Motivo inicial informado por el paciente",
                    ),
                    const SizedBox(height: 10),
                    _clinicalBlock(
                      context,
                      title: "Consulta inicial",
                      value: (consulta['motivo'] ?? "-").toString(),
                      icon: PhosphorIconsRegular.chatCircleText,
                    ),
                    if (historia != null) ...[
                      const SizedBox(height: 18),
                      _sectionTitle(
                        context,
                        "Historia clínica",
                        "Registro médico de la evaluación realizada en la consulta",
                      ),
                      if (signos != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if ((signos['ta'] ?? "").toString().isNotEmpty)
                              _infoChip(
                                context,
                                icon: PhosphorIconsRegular.heartbeat,
                                label: "TA",
                                value: signos['ta'].toString(),
                              ),
                            if ((signos['fc'] ?? "").toString().isNotEmpty)
                              _infoChip(
                                context,
                                icon: PhosphorIconsRegular.pulse,
                                label: "FC",
                                value: signos['fc'].toString(),
                              ),
                            if ((signos['temp'] ?? "").toString().isNotEmpty)
                              _infoChip(
                                context,
                                icon: PhosphorIconsRegular.thermometer,
                                label: "Temp",
                                value: "${signos['temp']}°C",
                                accent: const Color(0xFFF59E0B),
                              ),
                            if ((signos['sat'] ?? "").toString().isNotEmpty)
                              _infoChip(
                                context,
                                icon: PhosphorIconsRegular.heartbeat,
                                label: "SatO₂",
                                value: signos['sat'].toString(),
                                accent: const Color(0xFF0EA5E9),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (historia['respiratorio'] != null &&
                          historia['respiratorio'].toString().isNotEmpty) ...[
                        _clinicalBlock(
                          context,
                          title: "Examen respiratorio",
                          value: historia['respiratorio'].toString(),
                          icon: PhosphorIconsRegular.heartbeat,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (historia['cardio'] != null &&
                          historia['cardio'].toString().isNotEmpty) ...[
                        _clinicalBlock(
                          context,
                          title: "Examen cardiovascular",
                          value: historia['cardio'].toString(),
                          icon: PhosphorIconsRegular.heartStraight,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (historia['abdomen'] != null &&
                          historia['abdomen'].toString().isNotEmpty) ...[
                        _clinicalBlock(
                          context,
                          title: "Examen abdominal",
                          value: historia['abdomen'].toString(),
                          icon: PhosphorIconsRegular.firstAidKit,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (historia['snc'] != null &&
                          historia['snc'].toString().isNotEmpty) ...[
                        _clinicalBlock(
                          context,
                          title: "Sistema nervioso central",
                          value: historia['snc'].toString(),
                          icon: PhosphorIconsRegular.brain,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (historia['diagnostico'] != null &&
                          historia['diagnostico'].toString().isNotEmpty) ...[
                        _clinicalBlock(
                          context,
                          title: "Diagnóstico",
                          value: historia['diagnostico'].toString(),
                          icon: PhosphorIconsRegular.stethoscope,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (historia['observacion'] != null &&
                          historia['observacion'].toString().isNotEmpty)
                        _clinicalBlock(
                          context,
                          title: "Observaciones",
                          value: historia['observacion'].toString(),
                          icon: PhosphorIconsRegular.note,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF14B8A6),
                    ),
                  )
                : consultas.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _glassCard(
                            context,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.note,
                                  color: isDark
                                      ? Colors.white30
                                      : Colors.black26,
                                  size: 60,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No hay consultas registradas",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Cuando tengas atenciones médicas en DocYa, acá vas a ver tu historia clínica en orden cronológico.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black45,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _glassCard(
                                    context,
                                    radius: 28,
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 58,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF0EA896),
                                                    Color(0xFF2DD4BF),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF14B8A6,
                                                    ).withOpacity(0.24),
                                                    blurRadius: 18,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.timeline_rounded,
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
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF14B8A6,
                                                      ).withOpacity(
                                                        isDark ? 0.16 : 0.10,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Historia clínica",
                                                      style:
                                                          GoogleFonts.manrope(
                                                        color: const Color(
                                                          0xFF14B8A6,
                                                        ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    "Evolución del paciente",
                                                    style:
                                                        GoogleFonts.manrope(
                                                      fontSize: 28,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                          "Acá se registra tu línea de tiempo médica con cada consulta, su motivo, la evaluación clínica y el diagnóstico informado por el profesional.",
                                          style: GoogleFonts.manrope(
                                            fontSize: 14.5,
                                            height: 1.45,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            _infoChip(
                                              context,
                                              icon: PhosphorIconsRegular.files,
                                              label: "Consultas",
                                              value: consultas.length.toString(),
                                            ),
                                            _infoChip(
                                              context,
                                              icon: PhosphorIconsRegular.user,
                                              label: "Paciente",
                                              value: "Registro activo",
                                              accent:
                                                  const Color(0xFF0EA5E9),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverList.builder(
                              itemCount: consultas.length,
                              itemBuilder: (context, index) =>
                                  _timelineItem(context, consultas[index], index),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
