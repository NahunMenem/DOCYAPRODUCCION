import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/bottom_nav.dart';

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  final String _whatsappUrl =
      "https://wa.me/5491168700607?text=Hola%20necesito%20ayuda%20con%20DocYa";

  Future<void> _abrirWhatsApp() async {
    final url = Uri.parse(_whatsappUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception("No se pudo abrir WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final faqs = [
      (
        icon: FontAwesomeIcons.userDoctor,
        pregunta: "¿Cómo solicito un médico?",
        respuesta:
            "Ingresá tu dirección, respondé el filtro clínico y confirmá el pedido. Asignamos automáticamente al profesional más cercano."
      ),
      (
        icon: FontAwesomeIcons.creditCard,
        pregunta: "¿Cómo pago la consulta?",
        respuesta:
            "Podés pagar con tarjeta, transferencia o Mercado Pago desde la app."
      ),
      (
        icon: FontAwesomeIcons.triangleExclamation,
        pregunta: "¿Qué pasa si el médico no llega?",
        respuesta:
            "Si el profesional no llega, podés cancelar. El reembolso es automático."
      ),
      (
        icon: FontAwesomeIcons.userNurse,
        pregunta: "¿Puedo pedir un enfermero?",
        respuesta:
            "Sí. Si el médico lo considera necesario, podés solicitar un enfermero a tu domicilio."
      ),
      (
        icon: FontAwesomeIcons.receipt,
        pregunta: "¿Dónde veo mis recetas o certificados?",
        respuesta:
            "En tu perfil encontrás tus consultas, recetas y certificados firmados digitalmente."
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF04151C) : const Color(0xFFF5F7F8),
      bottomNavigationBar: DocYaBottomNav(
        selectedIndex: 3,
        onItemTapped: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/recetas');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/consultas');
              break;
            case 3:
              break;
          }
        },
      ),
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(
              left: -120,
              top: 60,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(20, 184, 166, 0.18),
                        Color.fromRGBO(20, 184, 166, 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -130,
              top: 180,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _glassCard(
                    context,
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
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF14B8A6).withOpacity(0.24),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.support_agent_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14B8A6).withOpacity(
                                        isDark ? 0.16 : 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      "Soporte DocYa",
                                      style: TextStyle(
                                        color: Color(0xFF14B8A6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Centro de ayuda",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
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
                          "Encontrá respuestas rápidas o hablá con nuestro equipo para resolver cualquier duda sobre tu atención.",
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _miniInfo(
                                context,
                                icon: Icons.schedule_rounded,
                                title: "Respuesta rápida",
                                subtitle: "Soporte por WhatsApp",
                                accentColor: const Color(0xFF14B8A6),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _miniInfo(
                                context,
                                icon: Icons.verified_user_rounded,
                                title: "Atención segura",
                                subtitle: "Equipo DocYa",
                                accentColor: const Color(0xFF0EA5E9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, "Preguntas frecuentes", "FAQ"),
                  const SizedBox(height: 14),
                  ...faqs.map(
                    (faq) => _faqItem(
                      context,
                      icono: faq.icon,
                      pregunta: faq.pregunta,
                      respuesta: faq.respuesta,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _glassCard(
                    context,
                    radius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0xFF25D366).withOpacity(
                                  isDark ? 0.18 : 0.12,
                                ),
                              ),
                              child: const Icon(
                                FontAwesomeIcons.whatsapp,
                                color: Color(0xFF25D366),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "¿Seguís con dudas?",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Escribinos por WhatsApp y te ayudamos.",
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF16C65B),
                                Color(0xFF25D366),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withOpacity(0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _abrirWhatsApp,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.whatsapp,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Hablar por WhatsApp",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: Color(0xFF14B8A6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _glassCard(
    BuildContext context, {
    required Widget child,
    double radius = 22,
    EdgeInsets? padding,
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
                : Colors.white.withOpacity(0.92),
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

  Widget _miniInfo(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : const Color(0xFFF8FBFB),
        border: Border.all(
          color: accentColor.withOpacity(isDark ? 0.24 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accentColor.withOpacity(isDark ? 0.18 : 0.12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqItem(
    BuildContext context, {
    required IconData icono,
    required String pregunta,
    required String respuesta,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _glassCard(
        context,
        radius: 20,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            iconColor: const Color(0xFF14B8A6),
            collapsedIconColor: const Color(0xFF14B8A6),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF14B8A6).withOpacity(
                  isDark ? 0.16 : 0.10,
                ),
              ),
              child: Icon(
                icono,
                color: const Color(0xFF14B8A6),
                size: 18,
              ),
            ),
            title: Text(
              pregunta,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  respuesta,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    height: 1.45,
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
