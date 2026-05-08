import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TeleconsultaFinalizadaScreen extends StatelessWidget {
  const TeleconsultaFinalizadaScreen({super.key});

  static const _primary  = Color(0xFF25D7C8);
  static const _secondary = Color(0xFF14B8A6);
  static const _textDark  = Color(0xFF04232A);

  Color _bgBase(bool isDark)    => isDark ? const Color(0xFF071820) : const Color(0xFFEEFBF9);
  Color _textMain(bool isDark)  => isDark ? const Color(0xFFD9ECF2) : const Color(0xFF0A2832);
  Color _textMuted(bool isDark) => isDark ? const Color(0xFF9FB6BD) : const Color(0xFF4A7A85);
  Color _cardBg(bool isDark)    => isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.94);
  Color _cardBorder(bool isDark) => isDark ? Colors.white.withOpacity(0.12) : _secondary.withOpacity(0.10);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _bgBase(isDark),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [_bgBase(isDark), const Color(0xFF0B2732), const Color(0xFF071820)]
                : [_bgBase(isDark), const Color(0xFFD9F2EF), const Color(0xFFEEFBF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Icono principal ──────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withOpacity(0.14),
                    border: Border.all(color: _primary, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(isDark ? 0.22 : 0.14),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    PhosphorIconsFill.checkCircle,
                    color: _primary,
                    size: 46,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Título ───────────────────────────────────────────────
                Text(
                  'Tu teleconsulta\nfinalizó correctamente',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: _textMain(isDark),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Subtexto ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _cardBg(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cardBorder(isDark)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.14)
                            : _secondary.withOpacity(0.07),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(PhosphorIconsRegular.heartbeat,
                          color: _primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Gracias por usar DocYa.\nEsperamos que te sientas mejor pronto.',
                          style: GoogleFonts.manrope(
                            color: _textMuted(isDark),
                            fontSize: 14.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // ── Botón volver al inicio ────────────────────────────────
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false),
                  icon: const Icon(PhosphorIconsRegular.house),
                  label: const Text('Volver al inicio'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: _primary,
                    foregroundColor: _textDark,
                    elevation: 0,
                    shadowColor: _primary.withOpacity(0.35),
                    textStyle: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
