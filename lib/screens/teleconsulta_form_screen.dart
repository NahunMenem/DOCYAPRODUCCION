import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import 'teleconsulta_waiting_screen.dart';

class TeleconsultaFormScreen extends StatefulWidget {
  final String pacienteUuid;

  const TeleconsultaFormScreen({super.key, required this.pacienteUuid});

  @override
  State<TeleconsultaFormScreen> createState() => _TeleconsultaFormScreenState();
}

class _TeleconsultaFormScreenState extends State<TeleconsultaFormScreen> {
  static const _bgBase = Color(0xFF071820);
  static const _surface = Color(0xFF102730);
  static const _primary = Color(0xFF25D7C8);
  static const _secondary = Color(0xFF14B8A6);
  static const _textMain = Color(0xFFD9ECF2);
  static const _textMuted = Color(0xFF9FB6BD);
  static const _textDark = Color(0xFF04232A);
  static const _warning = Color(0xFFFBBF24);

  final _motivoCtrl = TextEditingController();
  String _direccionGuardada = '';
  String _provinciaGuardada = '';
  String _localidadGuardada = '';
  String _detalleDireccion = '';
  bool _certificado = false;
  bool _consentimiento = false;
  bool _loading = false;
  bool _cargandoDireccion = true;

  @override
  void initState() {
    super.initState();
    _cargarDireccionGuardada();
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDireccionGuardada() async {
    setState(() => _cargandoDireccion = true);
    try {
      final res = await http.get(
        Uri.parse('$API_URL/direccion/mia/${widget.pacienteUuid}'),
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final direccion = (data['direccion'] ?? '').toString().trim();
        final partes = direccion
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final localidad =
            partes.length >= 2 ? partes[partes.length - 2] : direccion;
        final provincia = partes.length >= 3
            ? partes[partes.length - 2]
            : (partes.length >= 2 ? partes.last : 'Argentina');
        final detalles = [
          if ((data['piso'] ?? '').toString().trim().isNotEmpty)
            'Piso ${data['piso']}',
          if ((data['depto'] ?? '').toString().trim().isNotEmpty)
            'Depto ${data['depto']}',
          if ((data['indicaciones'] ?? '').toString().trim().isNotEmpty)
            data['indicaciones'].toString().trim(),
        ].join(' · ');

        setState(() {
          _direccionGuardada = direccion;
          _localidadGuardada = localidad;
          _provinciaGuardada = provincia;
          _detalleDireccion = detalles;
          _cargandoDireccion = false;
        });
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _cargandoDireccion = false);
  }

  Future<void> _crear() async {
    if (_motivoCtrl.text.trim().isEmpty ||
        _direccionGuardada.isEmpty ||
        !_consentimiento) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completá el motivo, cargá tu dirección y aceptá el consentimiento.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final res = await http.post(
      Uri.parse('$API_URL/teleconsultas'),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'paciente_uuid': widget.pacienteUuid,
        'motivo': _motivoCtrl.text.trim(),
        'direccion': _direccionGuardada,
        'provincia':
            _provinciaGuardada.isEmpty ? 'Argentina' : _provinciaGuardada,
        'localidad': _localidadGuardada.isEmpty
            ? _direccionGuardada
            : _localidadGuardada,
        'necesita_certificado': _certificado,
        'consentimiento_teleconsulta': _consentimiento,
      }),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la teleconsulta.')),
      );
      return;
    }

    final data = jsonDecode(res.body);
    await prefs.setString('teleconsulta_activa_id', data['id'].toString());
    final rawExpiresAt = (data['expires_at'] ?? '').toString();
    final parsedExpiresAt = DateTime.tryParse(rawExpiresAt)?.toLocal();
    final expiresAt = parsedExpiresAt != null &&
            parsedExpiresAt.isAfter(
              DateTime.now().subtract(const Duration(seconds: 10)),
            )
        ? parsedExpiresAt
        : DateTime.now().add(const Duration(minutes: 5));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TeleconsultaWaitingScreen(
          consultaId: data['id'],
          pacienteUuid: widget.pacienteUuid,
          expiresAt: expiresAt,
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.manrope(color: _textMain, fontWeight: FontWeight.w600),
      cursorColor: _primary,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _primary, size: 20),
        labelText: label,
        labelStyle:
            GoogleFonts.manrope(color: _textMuted, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _direccionCard() {
    final sinDireccion = _direccionGuardada.isEmpty && !_cargandoDireccion;
    final subtitle = _cargandoDireccion
        ? 'Buscando dirección guardada...'
        : (sinDireccion
            ? 'No encontramos una dirección cargada en tu perfil.'
            : _direccionGuardada);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (sinDireccion ? _warning : _primary).withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: _cargandoDireccion
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  )
                : Icon(
                    sinDireccion
                        ? PhosphorIconsRegular.warning
                        : PhosphorIconsRegular.mapPin,
                    color: sinDireccion ? _warning : _primary,
                    size: 21,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dirección de referencia',
                  style: GoogleFonts.manrope(
                    color: _textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: sinDireccion ? _warning : _textMuted,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_detalleDireccion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _detalleDireccion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: _textMuted.withOpacity(0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(value ? 0.09 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: value
                ? _primary.withOpacity(0.50)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? _primary : _textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: _textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      color: _textMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeColor: _primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBase,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgBase, Color(0xFF0B2732), Color(0xFF071820)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      PhosphorIconsRegular.arrowLeft,
                      color: _textMain,
                    ),
                  ),
                  Text(
                    'Teleconsulta',
                    style: GoogleFonts.manrope(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    colors: [_secondary, Color(0xFF0B3440)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _secondary.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primary,
                      ),
                      child: const Icon(
                        PhosphorIconsFill.videoCamera,
                        color: _textDark,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atención online',
                            style: GoogleFonts.manrope(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Un médico por videollamada',
                            style: GoogleFonts.manrope(
                              color: _textMain,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Te avisamos cuando un profesional acepta la consulta.',
                            style: GoogleFonts.manrope(
                              color: _textMain.withOpacity(0.78),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _glass(
                child: Column(
                  children: [
                    _field(
                      label: 'Motivo de consulta',
                      controller: _motivoCtrl,
                      icon: PhosphorIconsRegular.stethoscope,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    _direccionCard(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _toggleTile(
                icon: PhosphorIconsRegular.fileText,
                title: 'Certificado médico',
                subtitle: 'Lo solicitás para que el profesional lo evalúe.',
                value: _certificado,
                onChanged: (v) => setState(() => _certificado = v),
              ),
              const SizedBox(height: 10),
              _toggleTile(
                icon: PhosphorIconsRegular.shieldCheck,
                title: 'Consentimiento obligatorio',
                subtitle: 'Acepto realizar la atención por teleconsulta.',
                value: _consentimiento,
                onChanged: (v) => setState(() => _consentimiento = v),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _loading || _cargandoDireccion ? null : _crear,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _textDark,
                        ),
                      )
                    : const Icon(PhosphorIconsBold.videoCamera),
                label: Text(_loading ? 'Creando...' : 'Confirmar teleconsulta'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: _primary,
                  disabledBackgroundColor: _primary.withOpacity(0.45),
                  foregroundColor: _textDark,
                  textStyle: GoogleFonts.manrope(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
