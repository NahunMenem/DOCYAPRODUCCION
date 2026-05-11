import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SolicitarScreen extends StatelessWidget {
  final VoidCallback onMedico;
  final VoidCallback onEnfermero;
  final VoidCallback onTeleconsulta;

  const SolicitarScreen({
    super.key,
    required this.onMedico,
    required this.onEnfermero,
    required this.onTeleconsulta,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF04151C),
                  Color(0xFF0B222B),
                  Color(0xFF061A21),
                ]
              : const [
                  Color(0xFFF8FBFD),
                  Colors.white,
                  Color(0xFFF3FAF8),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE6EEF2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Solicitar",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF071238),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "¿Que necesitas hoy?",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF071238),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Elegi la opcion que mejor se adapte a lo que necesitas.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF536078),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 380;
                  return GridView.count(
                    crossAxisCount: compact ? 1 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: compact ? 1.45 : 0.82,
                    children: [
                      _RequestOptionCard(
                        title: "Medico a domicilio",
                        description: "Consulta general en tu casa.",
                        pill: "30-45 min",
                        icon: PhosphorIconsFill.stethoscope,
                        color: const Color(0xFF0F8F85),
                        isDark: isDark,
                        onTap: onMedico,
                      ),
                      _RequestOptionCard(
                        title: "Enfermero a domicilio",
                        description: "Curaciones, inyectables y controles.",
                        pill: "30-45 min",
                        icon: PhosphorIconsFill.syringe,
                        color: const Color(0xFF6550B6),
                        isDark: isDark,
                        onTap: onEnfermero,
                      ),
                      _RequestOptionCard(
                        title: "Teleconsulta",
                        description: "Consulta por videollamada.",
                        pill: "5-10 min",
                        icon: PhosphorIconsFill.videoCamera,
                        color: const Color(0xFF1E63B7),
                        isDark: isDark,
                        onTap: onTeleconsulta,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF14B8A6).withOpacity(isDark ? 0.14 : 0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsFill.shieldCheck,
                      color: Color(0xFF08786F),
                      size: 34,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Profesionales verificados",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF08786F),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Medicos y enfermeros matriculados y verificados por DocYa.",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF17324D),
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final String pill;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _RequestOptionCard({
    required this.title,
    required this.description,
    required this.pill,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE3EBF1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(isDark ? 0.20 : 0.12),
                  ),
                  child: Icon(icon, color: color, size: 34),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            isDark ? Colors.white70 : const Color(0xFF071238),
                        fontSize: 12.5,
                        height: 1.28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: color, size: 15),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        pill,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: color, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
