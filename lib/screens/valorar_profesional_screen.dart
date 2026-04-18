import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'gracias_screen.dart';

class ValorarProfesionalScreen extends StatefulWidget {
  final int? consultaId;
  final String pacienteUuid;
  final int profesionalId;
  final String tipo; // "medico" o "enfermero"

  const ValorarProfesionalScreen({
    super.key,
    this.consultaId,
    required this.pacienteUuid,
    required this.profesionalId,
    required this.tipo,
  });

  @override
  State<ValorarProfesionalScreen> createState() =>
      _ValorarProfesionalScreenState();
}

class _ValorarProfesionalScreenState extends State<ValorarProfesionalScreen> {
  int _rating = 0;
  final TextEditingController _comentarioCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _enviarValoracion() async {
    setState(() => _loading = true);

    final Map<String, dynamic> body = {
      "paciente_uuid": widget.pacienteUuid,
      "puntaje": _rating,
      "comentario": _comentarioCtrl.text.trim(),
    };

    if (widget.tipo == "medico") body["medico_id"] = widget.profesionalId;
    if (widget.tipo == "enfermero") body["enfermero_id"] = widget.profesionalId;

    final response = await http.post(
      Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/valorar"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GraciasScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 Logo segun modo
    final String logoUrl = isDark
        ? "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logoblanco_1_qdlnog.png"
        : "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logo_1_svfdye.png";

    final titulo = "¿Cómo fue tu experiencia con el profesional?";

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Valorar atención",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                // 🔥 LOGO DOCYA
                Image.network(
                  logoUrl,
                  height: 55,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 30),

                /// ----- CARD GLASS PREMIUM -----
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            spreadRadius: 1,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),

                      child: Column(
                        children: [
                          // TÍTULO
                          Text(
                            titulo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 28),

                          // ⭐ Estrellas animadas
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final bool activo = index < _rating;

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _rating = index + 1);
                                },
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutBack,
                                  scale: activo ? 1.25 : 1.0,
                                  child: Icon(
                                    activo
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: Colors.tealAccent,
                                    size: 40,
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 32),

                          // Comentario
                          TextField(
                            controller: _comentarioCtrl,
                            maxLines: 5,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Escribe un comentario profesional...",
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Colors.tealAccent, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.tealAccent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 35),

                          // Botón Enviar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _loading || _rating == 0 ? null : _enviarValoracion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 8,
                                shadowColor: Colors.tealAccent.withOpacity(0.45),
                              ),
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Enviar valoración",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

}
