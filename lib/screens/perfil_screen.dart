import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'consultas_screen.dart';
import 'medicacion_screen.dart';
import 'payment_methods_screen.dart';
import 'recetas_screen.dart';
import 'soporte_screen.dart';

class PerfilScreen extends StatefulWidget {
  final String userId;

  const PerfilScreen({super.key, required this.userId});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const Color kPrimary = Color(0xFF14B8A6);

  bool cargando = true;
  String nombre = "";
  String email = "";
  String? fotoUrl;
  String? _userToken;
  int totalConsultas = 0;
  int mesesEnDocYa = 0;

  double w(BuildContext c) => MediaQuery.of(c).size.width;
  double h(BuildContext c) => MediaQuery.of(c).size.height;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor =>
      _isDark ? const Color(0xFF04151C) : const Color(0xFFF5F7F8);
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary => _isDark ? Colors.white70 : Colors.black54;

  @override
  void initState() {
    super.initState();
    _cargarTokenYPerfil();
  }

  Future<void> _cargarTokenYPerfil() async {
    final prefs = await SharedPreferences.getInstance();
    _userToken = prefs.getString("auth_token") ?? prefs.getString("token");
    await _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/users/${widget.userId}",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        setState(() {
          nombre = (data['full_name'] ?? "").toString();
          email = (data['email'] ?? "").toString();
          fotoUrl = (data['foto_url'] ?? "").toString().trim().isEmpty
              ? null
              : (data['foto_url'] ?? "").toString();
          totalConsultas = data['consultas_count'] ?? 0;
          mesesEnDocYa = data['meses_en_docya'] ?? 0;
          cargando = false;
        });
      } else {
        cargando = false;
      }
    } catch (_) {
      cargando = false;
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/login");
  }

  void _confirmarEliminacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark
              ? Colors.black.withOpacity(0.85)
              : Colors.white.withOpacity(0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "Eliminar cuenta",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Esta accion eliminara tu cuenta y todos tus datos de forma permanente. No podras recuperarla.",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancelar",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _eliminarCuenta();
              },
              child: const Text(
                "Eliminar",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarCuenta() async {
    try {
      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/usuarios/${widget.userId}/delete",
      );

      final response = await http.delete(url);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cuenta eliminada correctamente"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al eliminar cuenta: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error inesperado: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _glass({
    required Widget child,
    double radius = 22,
    EdgeInsets? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isDark
                  ? [
                      Colors.white.withOpacity(0.10),
                      Colors.white.withOpacity(0.05),
                    ]
                  : [
                      Colors.white.withOpacity(0.98),
                      const Color(0xFFF7FFFD),
                    ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: _isDark
                  ? Colors.white.withOpacity(0.14)
                  : kPrimary.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isDark
                    ? Colors.black.withOpacity(0.18)
                    : kPrimary.withOpacity(0.08),
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

  Widget _sectionTitle(String title, String badge) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(_isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: kPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileHero(double ancho) {
    return _glass(
      radius: 30,
      padding: const EdgeInsets.all(22),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(_isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Mi perfil",
                        style: TextStyle(
                          color: kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      nombre.isEmpty ? "Usuario" : nombre,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: ancho < 380 ? 24 : 30,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email.isEmpty ? "Tu cuenta DocYa" : email,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: ancho < 380 ? 13 : 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: ancho < 380 ? 88 : 104,
                height: ancho < 380 ? 88 : 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
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
                      color: kPrimary.withOpacity(0.25),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: fotoUrl != null
                      ? Image.network(
                          fotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0EA896).withOpacity(0.95),
                  const Color(0xFF14B8A6).withOpacity(0.90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Tu espacio personal",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Administra consultas, recetas, medicacion y soporte desde un solo lugar.",
                        style: TextStyle(
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _cerrarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    "Salir",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color accentColor = kPrimary,
    bool destructive = false,
  }) {
    return _glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: destructive
                    ? Colors.redAccent.withOpacity(_isDark ? 0.16 : 0.10)
                    : accentColor.withOpacity(_isDark ? 0.18 : 0.12),
              ),
              child: Icon(
                icon,
                color: destructive ? Colors.redAccent : accentColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: w(context) < 380 ? 14 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: w(context) < 380 ? 11 : 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: _isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    final ancho = w(context);

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          if (_isDark) ...[
            Positioned(
              left: -120,
              top: 40,
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
              top: 120,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(45, 212, 191, 0.16),
                        Color.fromRGBO(45, 212, 191, 0.07),
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
              padding: EdgeInsets.fromLTRB(
                20,
                h(context) * 0.02,
                20,
                h(context) * 0.04,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileHero(ancho),
                  const SizedBox(height: 24),
                  _sectionTitle("Resumen de actividad", "DocYa"),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _statCard(
                            "Consultas medicas",
                            totalConsultas.toString(),
                            Icons.monitor_heart_outlined,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _statCard(
                            "Meses en DocYa",
                            mesesEnDocYa.toString(),
                            Icons.calendar_month_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle("Accesos rapidos", "Cuenta"),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: ancho < 720 ? 1 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: ancho < 720 ? 2.4 : 2.2,
                    children: [
                      _tile(
                        icon: Icons.history_rounded,
                        title: "Historial de consultas",
                        subtitle: "Ver mis visitas y diagnosticos",
                        accentColor: const Color(0xFF14B8A6),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ConsultasScreen(pacienteUuid: widget.userId),
                          ),
                        ),
                      ),
                      _tile(
                        icon: Icons.receipt_long_rounded,
                        title: "Recetas y certificados",
                        subtitle: "Ver documentos emitidos",
                        accentColor: const Color(0xFF0EA5E9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecetasScreen(
                              pacienteUuid: widget.userId,
                              token: _userToken ?? "",
                            ),
                          ),
                        ),
                      ),
                      _tile(
                        icon: Icons.medication_liquid_rounded,
                        title: "Mi medicacion",
                        subtitle: "Recordatorios, tomas e historial",
                        accentColor: const Color(0xFF22C55E),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MedicacionScreen(
                              pacienteUuid: widget.userId,
                            ),
                          ),
                        ),
                      ),
                      _tile(
                        icon: Icons.credit_card_rounded,
                        title: "Metodos de pago",
                        subtitle: "Gestionar tarjetas guardadas",
                        accentColor: const Color(0xFF14B8A6),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentMethodsScreen(
                                pacienteUuid: widget.userId),
                          ),
                        ),
                      ),
                      _tile(
                        icon: Icons.support_agent_rounded,
                        title: "Soporte",
                        subtitle: "Centro de ayuda y contacto",
                        accentColor: const Color(0xFFF59E0B),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SoporteScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle("Privacidad", "Importante"),
                  const SizedBox(height: 14),
                  _glass(
                    radius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Zona sensible",
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Gestiona aqui acciones permanentes sobre tu cuenta y tus datos.",
                          style: TextStyle(
                            color: _textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _tile(
                          icon: Icons.delete_forever_rounded,
                          title: "Eliminar cuenta",
                          subtitle: "Borrar mi cuenta y todos mis datos",
                          destructive: true,
                          onTap: () => _confirmarEliminacion(context),
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

  Widget _statCard(String title, String value, IconData icon) {
    return _glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: kPrimary.withOpacity(_isDark ? 0.18 : 0.12),
            ),
            child: Icon(icon, color: kPrimary, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.25,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
