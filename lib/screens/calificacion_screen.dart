import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// importa la pantalla de agradecimiento
import 'gracias_screen.dart';

class ValorarMedicoScreen extends StatefulWidget {
  final int consultaId;
  final String pacienteUuid;
  final int medicoId;

  const ValorarMedicoScreen({
    super.key,
    required this.consultaId,
    required this.pacienteUuid,
    required this.medicoId,
  });

  @override
  State<ValorarMedicoScreen> createState() => _ValorarMedicoScreenState();
}

class _ValorarMedicoScreenState extends State<ValorarMedicoScreen> {
  int _rating = 0;
  final TextEditingController _comentarioCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _enviarValoracion() async {
    setState(() => _loading = true);

    final response = await http.post(
      Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/valorar"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "paciente_uuid": widget.pacienteUuid,
        "medico_id": widget.medicoId,
        "puntaje": _rating,
        "comentario": _comentarioCtrl.text.trim(),
      }),
    );

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      // 👉 Ir directo a pantalla de agradecimiento
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Valorar atención"),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "¿Cómo fue tu experiencia con el médico?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // ⭐ Estrellas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          return IconButton(
                            icon: Icon(
                              i < _rating ? Icons.star : Icons.star_border,
                              color: Colors.tealAccent,
                              size: 36,
                            ),
                            onPressed: () {
                              setState(() => _rating = i + 1);
                            },
                          );
                        }),
                      ),

                      const SizedBox(height: 20),

                      // Comentario
                      TextField(
                        controller: _comentarioCtrl,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Escribe un comentario profesional...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.tealAccent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Colors.tealAccent, width: 2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Botón enviar
                      ElevatedButton(
                        onPressed:
                            _loading || _rating == 0 ? null : _enviarValoracion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Enviar valoración",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
