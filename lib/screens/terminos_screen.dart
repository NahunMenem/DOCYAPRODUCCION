import 'dart:ui';
import 'package:flutter/material.dart';

class TerminosScreen extends StatelessWidget {
  const TerminosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const kPrimary = Color(0xFF14B8A6);

    final darkGradient = const [
      Color(0xFF0F2027),
      Color(0xFF203A43),
      Color(0xFF2C5364),
    ];

    final lightGradient = const [
      Color(0xFFE8F5F3),
      Color(0xFFD9EFED),
    ];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? darkGradient : lightGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔹 Header con logo responsive
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      isDark
                          ? "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logoblanco_1_qdlnog.png"
                          : "https://res.cloudinary.com/dqsacd9ez/image/upload/v1757197807/logo_1_svfdye.png",
                      height: 40,
                    ),
                  ],
                ),
              ),

              Text(
                "Términos y Condiciones",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 📜 Contenedor glass responsive
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isDark ? Colors.white24 : Colors.black26,
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          """
🩺 Consentimiento informado y Términos de uso

Declaro bajo juramento que:

1️⃣ He leído y acepto los Términos y Condiciones y la Política de Privacidad de DocYa.  

2️⃣ Entiendo que DocYa es una plataforma tecnológica que conecta pacientes con médicos y enfermeros, y que no se responsabiliza por los actos médicos que se realicen durante la atención.  

3️⃣ Comprendo que DocYa no brinda servicios de urgencias ni emergencias médicas. En caso de emergencia debo comunicarme al 911 o dirigirme al centro de salud más cercano.  

4️⃣ Autorizo a que mis datos personales y de salud sean tratados conforme a la Ley 25.326 de Protección de Datos Personales en Argentina.  

5️⃣ Manifiesto haber brindado información cierta y completa en el registro y en los formularios de triage previos a cada consulta.
                          """,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 15,
                            height: 1.55,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ✅ Botón aceptar
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      "Aceptar y continuar",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
