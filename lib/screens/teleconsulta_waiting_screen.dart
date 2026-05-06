import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import 'teleconsulta_room_screen.dart';

class TeleconsultaWaitingScreen extends StatefulWidget {
  final int consultaId;
  final String pacienteUuid;
  final DateTime expiresAt;

  const TeleconsultaWaitingScreen({
    super.key,
    required this.consultaId,
    required this.pacienteUuid,
    required this.expiresAt,
  });

  @override
  State<TeleconsultaWaitingScreen> createState() => _TeleconsultaWaitingScreenState();
}

class _TeleconsultaWaitingScreenState extends State<TeleconsultaWaitingScreen> {
  static const _bgBase = Color(0xFF071820);
  static const _surface = Color(0xFF102730);
  static const _primary = Color(0xFF25D7C8);
  static const _warning = Color(0xFFFBBF24);
  static const _textMain = Color(0xFFD9ECF2);
  static const _textMuted = Color(0xFF9FB6BD);
  static const _textDark = Color(0xFF04232A);

  Timer? _timer;
  Timer? _poller;
  Duration _remaining = Duration.zero;
  Map<String, dynamic>? _consulta;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _poller = Timer.periodic(const Duration(seconds: 4), (_) => _fetch());
    _fetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  void _tick() {
    final diff = widget.expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  Future<void> _fetch() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final uri = Uri.parse('$API_URL/teleconsultas/${widget.consultaId}').replace(
      queryParameters: {'paciente_uuid': widget.pacienteUuid},
    );
    final res = await http.get(
      uri,
      headers: {if (token.isNotEmpty) 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200 || !mounted) return;
    setState(() => _consulta = jsonDecode(res.body));
  }

  Future<void> _cancelar() async {
    setState(() => _cancelando = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    await http.post(
      Uri.parse('$API_URL/teleconsultas/${widget.consultaId}/cancelar'),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'paciente_uuid': widget.pacienteUuid}),
    );
    await prefs.remove('teleconsulta_activa_id');
    if (mounted) Navigator.of(context).pop();
  }

  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = (_consulta?['estado'] ?? 'buscando_medico').toString();
    final asignada = estado == 'asignada' || estado == 'en_videollamada';
    final expirada = estado == 'cancelada_sin_medico' || _remaining == Duration.zero;
    final minutes = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final progress = (_remaining.inSeconds / 300).clamp(0.0, 1.0);

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Teleconsulta #${widget.consultaId}', style: GoogleFonts.manrope(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                const Spacer(),
                _glass(
                  child: Column(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (asignada ? _primary : expirada ? _warning : _primary).withOpacity(0.14),
                          border: Border.all(color: asignada ? _primary : expirada ? _warning : _primary, width: 1.4),
                        ),
                        child: Icon(
                          asignada
                              ? PhosphorIconsFill.videoCamera
                              : expirada
                                  ? PhosphorIconsRegular.clockClockwise
                                  : PhosphorIconsRegular.stethoscope,
                          color: asignada ? _primary : expirada ? _warning : _primary,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        asignada
                            ? 'Tu médico está disponible'
                            : expirada
                                ? 'No encontramos médicos disponibles'
                                : 'Buscando un médico disponible',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(color: _textMain, fontSize: 24, height: 1.12, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        asignada
                            ? '${_consulta?['medico_nombre'] ?? 'Profesional'}\nMatrícula: ${_consulta?['medico_matricula'] ?? '-'}'
                            : expirada
                                ? 'No se realizó ningún cobro.'
                                : 'Te mantenemos en sala de espera durante 5 minutos.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(color: _textMuted, fontSize: 14.5, height: 1.42, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),
                      if (!asignada && !expirada) ...[
                        Text('$minutes:$seconds', style: GoogleFonts.manrope(color: _primary, fontSize: 42, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation(_primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                if (asignada)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TeleconsultaRoomScreen(
                            consultaId: widget.consultaId,
                            pacienteUuid: widget.pacienteUuid,
                            roomUrl: (_consulta?['daily_room_url'] ?? _consulta?['video_url']).toString(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(PhosphorIconsBold.videoCamera),
                    label: const Text('Entrar a videollamada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: _textDark,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w900),
                    ),
                  )
                else if (!expirada)
                  OutlinedButton.icon(
                    onPressed: _cancelando ? null : _cancelar,
                    icon: const Icon(PhosphorIconsRegular.xCircle),
                    label: Text(_cancelando ? 'Cancelando...' : 'Cancelar búsqueda'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textMain,
                      minimumSize: const Size(double.infinity, 54),
                      side: BorderSide(color: Colors.white.withOpacity(0.16)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                    child: const Text('Volver'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
