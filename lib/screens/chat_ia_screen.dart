import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart';
import 'filtro_medico_screen.dart';

class ChatIAScreen extends StatefulWidget {
  final String? direccion;
  final LatLng? ubicacion;

  const ChatIAScreen({
    super.key,
    this.direccion,
    this.ubicacion,
  });

  @override
  State<ChatIAScreen> createState() => _ChatIAScreenState();
}

class _ChatIAScreenState extends State<ChatIAScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _cargando = false;
  bool _recomiendaMedico = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content':
          'Hola, soy DocYa IA.\n\nPuedo orientarte con tus síntomas y ayudarte a decidir si te conviene pedir atención médica.\n\n¿Qué síntomas estás teniendo?',
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _cargando) return;

    setState(() {
      _messages.add({'role': 'user', 'content': texto});
      _inputCtrl.clear();
      _cargando = true;
    });
    _scrollAlFinal();

    try {
      final historial = _messages
          .where(
            (m) => !(m['role'] == 'assistant' &&
                m['content']!.contains('DocYa IA')),
          )
          .toList();

      final response = await http.post(
        Uri.parse('$API_URL/chat-ia'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': historial}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': data['response'] as String,
          });
          if (data['recomienda_medico'] == true) {
            _recomiendaMedico = true;
          }
          _cargando = false;
        });
      } else {
        _mostrarError();
      }
    } catch (_) {
      if (mounted) _mostrarError();
    }

    _scrollAlFinal();
  }

  void _mostrarError() {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content':
            'Hubo un problema al conectarme. Intentá de nuevo en un momento.',
      });
      _cargando = false;
    });
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _irASolicitarMedico() async {
    if (widget.ubicacion != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FiltroMedicoScreen(
            direccion: widget.direccion ?? '',
            ubicacion: widget.ubicacion!,
          ),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final res = await http.get(Uri.parse('$API_URL/direccion/mia/$userId'));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final ubicacion = LatLng(data['lat'], data['lng']);
        final direccion = data['direccion'] ?? '';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FiltroMedicoScreen(
              direccion: direccion,
              ubicacion: ubicacion,
            ),
          ),
        );
      } else {
        _mostrarSnack('No se pudo cargar tu dirección');
      }
    } catch (_) {
      if (mounted) _mostrarSnack('No se pudo cargar tu dirección');
    }
  }

  void _mostrarSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _buildBurbuja(Map<String, String> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final esAsistente = msg['role'] == 'assistant';

    return Align(
      alignment: esAsistente ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        child: Column(
          crossAxisAlignment:
              esAsistente ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (esAsistente)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsFill.robot,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'DocYa IA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(esAsistente ? 6 : 22),
                bottomRight: Radius.circular(esAsistente ? 22 : 6),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: esAsistente
                        ? (isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.88))
                        : const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(esAsistente ? 6 : 22),
                      bottomRight: Radius.circular(esAsistente ? 22 : 6),
                    ),
                    border: esAsistente
                        ? Border.all(
                            color: const Color(0xFF14B8A6).withOpacity(0.16),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    msg['content']!,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: esAsistente
                          ? (isDark ? Colors.white : const Color(0xFF12303A))
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonSolicitarMedico() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 8,
        ),
        onPressed: _irASolicitarMedico,
        icon: const Icon(
          PhosphorIconsFill.firstAid,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          'Solicitar médico ahora',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildIndicadorEscribiendo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(
            color: const Color(0xFF14B8A6).withOpacity(0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _puntito(delay: 0),
            const SizedBox(width: 4),
            _puntito(delay: 200),
            const SizedBox(width: 4),
            _puntito(delay: 400),
          ],
        ),
      ),
    );
  }

  Widget _puntito({required int delay}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeInOut,
      onEnd: () => setState(() {}),
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF14B8A6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF12303A),
                  Color(0xFF0E7490),
                  Color(0xFF14B8A6),
                ]
              : const [
                  Color(0xFFE6FFFB),
                  Color(0xFFD9FFFA),
                  Color(0xFFCCFBF1),
                ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.16)
                  : Colors.white.withOpacity(0.86),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              PhosphorIconsFill.sparkle,
              color: isDark ? Colors.white : const Color(0xFF0F766E),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DocYa IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF092F37),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Orientación inicial de síntomas',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF28515B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF08171D) : const Color(0xFFF5FFFE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(PhosphorIconsFill.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildHeaderCard(),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.24)),
            ),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsFill.warning,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esto es una orientación inicial y no reemplaza una consulta médica.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _messages.length + (_cargando ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildIndicadorEscribiendo();
                }
                return _buildBurbuja(_messages[index]);
              },
            ),
          ),
          if (_recomiendaMedico) _buildBotonSolicitarMedico(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.96),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    onSubmitted: (_) => _enviarMensaje(),
                    decoration: InputDecoration(
                      hintText: 'Contame tus síntomas...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.07)
                          : const Color(0xFFF4F7F8),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _enviarMensaje,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _cargando ? Colors.grey : const Color(0xFF14B8A6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF14B8A6).withOpacity(0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      PhosphorIconsFill.paperPlaneTilt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
