import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 👇 importamos la pantalla genérica de valoración
import 'valorar_profesional_screen.dart';

class ConsultaEnCursoScreen extends StatefulWidget {
  final int? consultaId;

  final int profesionalId; // 👈 genérico (médico o enfermero)
  final String pacienteUuid;
  final String nombreProfesional;
  final String especialidad; // 🔥 YA NO SE USA
  final String matricula;
  final String motivo;
  final String direccion;
  final String horaInicio;
  final String tipo; // 👈 "medico" o "enfermero"

  const ConsultaEnCursoScreen({
    super.key,
    this.consultaId,
    required this.profesionalId,
    required this.pacienteUuid,
    required this.nombreProfesional,
    required this.especialidad,
    required this.matricula,
    required this.motivo,
    required this.direccion,
    required this.horaInicio,
    required this.tipo,
  });

  @override
  State<ConsultaEnCursoScreen> createState() => _ConsultaEnCursoScreenState();
}

class _ConsultaEnCursoScreenState extends State<ConsultaEnCursoScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  String? horaFin;

  @override
  void initState() {
    super.initState();
    _guardarConsultaActiva();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // 🔄 revisar estado cada 10s
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkEstadoConsulta();
    });
  }

  Future<void> _checkEstadoConsulta() async {
    try {
      final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["estado"] == "finalizada") {
          horaFin = DateFormat("HH:mm").format(DateTime.now());
          await _limpiarConsultaActiva();

          _timer?.cancel();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ValorarProfesionalScreen(
                  consultaId: widget.consultaId,
                  pacienteUuid: widget.pacienteUuid,
                  profesionalId: widget.profesionalId,
                  tipo: widget.tipo,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error consultando estado: $e");
    }
  }

  Future<void> _guardarConsultaActiva() async {
    if (widget.consultaId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("consulta_activa_id", widget.consultaId.toString());
  }

  Future<void> _limpiarConsultaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("consulta_activa_id");
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget glassCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: Colors.white.withOpacity(0.15))
                : Border.all(color: Colors.black12),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    final titulo = "Tu consulta con el profesional está en curso.";
    final tituloProfesional =
        widget.tipo == "enfermero" ? "Enfermero/a" : "Dr/a";

    return Scaffold(
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : const BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // LOGO
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Image.asset(
                              isDark ? "assets/logoblanco.png" : "assets/logonegro.png",
                              height: 40,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // AVATAR ANIMADO
                        Center(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Container(
                                width: 140,
                                height: 140,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.tealAccent.withOpacity(
                                          0.5 * (1 - _controller.value)),
                                      blurRadius: 30 * (1 - _controller.value),
                                      spreadRadius: 20 * (1 - _controller.value),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFF14B8A6),
                                  child: Text(
                                    widget.nombreProfesional[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // CARD PROFESIONAL
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: glassCard(
                            child: Column(
                              children: [
                                Text(
                                  "$tituloProfesional ${widget.nombreProfesional}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Matrícula: ${widget.matricula}",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // INFO CONSULTA
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              glassCard(
                                child: Row(
                                  children: [
                                    const Icon(Icons.note_alt,
                                        color: Colors.tealAccent, size: 26),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Motivo: ${widget.motivo}",
                                        style:
                                            TextStyle(color: textColor, fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              glassCard(
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule,
                                        color: Colors.tealAccent, size: 26),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Inicio: ${widget.horaInicio} (ARG)",
                                        style:
                                            TextStyle(color: textColor, fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (horaFin != null) ...[
                                const SizedBox(height: 12),
                                glassCard(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.tealAccent, size: 26),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Finalización: $horaFin (ARG)",
                                          style: TextStyle(
                                              color: textColor, fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              glassCard(
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.tealAccent, size: 26),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        widget.direccion,
                                        style:
                                            TextStyle(color: textColor, fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // FOOTER (SE EXPANDE SI QUEDA ESPACIO)
                        Expanded(
                          child: Container(),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Text(
                            "$titulo\nCuando finalice podrás calificar la atención.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

}
