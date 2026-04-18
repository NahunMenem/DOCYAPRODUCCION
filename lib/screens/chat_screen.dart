import 'dart:convert';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../globals.dart';

class ChatScreen extends StatefulWidget {
  final int? consultaId;
  final String remitenteTipo;
  final String remitenteId;

  const ChatScreen({
    super.key,
    this.consultaId,
    required this.remitenteTipo,
    required this.remitenteId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color _bgBase = Color(0xFF071821);
  static const Color _bgSurface = Color(0xFF102A34);
  static const Color _accent = Color(0xFF28D7C7);
  static const Color _accentSoft = Color(0xFF17B7AA);
  static const Color _textMain = Color(0xFFE4F3F6);
  static const Color _textMuted = Color(0xFF8DAAB2);
  static const Color _glassBorder = Color(0xFF2E525C);

  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  WebSocketChannel? _channel;
  bool _showNewMsgIndicator = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _connectWebSocket();
    _loadHistory();
  }

  void _initAudioPlayer() {
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.stop();
      await Future.delayed(const Duration(milliseconds: 40));
      await _audioPlayer.play(
        AssetSource('sounds/alerta.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('Error sonido: $e');
    }
  }

  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 180, amplitude: 180);
      }
    } catch (_) {}
  }

  void _mostrarNotificacionVisual() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _accentSoft.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(
          'Nuevo mensaje recibido',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _connectWebSocket() {
    final url =
        'wss://docya-railway-production.up.railway.app/ws/chat/${widget.consultaId}/${widget.remitenteTipo}/${widget.remitenteId}';

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event);
          if (data is! Map<String, dynamic>) return;

          setState(() => _messages.add(data));

          final esMio = data['remitente_tipo'] == widget.remitenteTipo &&
              data['remitente_id'].toString() == widget.remitenteId;

          if (!esMio) {
            _vibrate();
            _playSound();
            _mostrarNotificacionVisual();
          }

          if (_scrollController.hasClients &&
              _scrollController.offset >=
                  _scrollController.position.maxScrollExtent - 100) {
            Future.delayed(const Duration(milliseconds: 250), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              }
            });
          } else {
            setState(() => _showNewMsgIndicator = true);
          }
        } catch (e) {
          debugPrint('Error WS: $e');
        }
      },
      onDone: () {
        Future.delayed(const Duration(seconds: 2), _connectWebSocket);
      },
      onError: (err) {
        debugPrint('Error WS: $err');
      },
    );
  }

  Future<void> _loadHistory() async {
    final resp = await http.get(
      Uri.parse('$API_URL/consultas/${widget.consultaId}/chat'),
    );

    if (resp.statusCode == 200) {
      final List<dynamic> list = jsonDecode(resp.body);
      setState(() {
        _messages.addAll(list.map((e) => e as Map<String, dynamic>).toList());
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty || _channel == null) return;

    _channel!.sink.add(jsonEncode({'mensaje': _controller.text.trim()}));
    _controller.clear();
    _vibrate();
    _playSound();
  }

  bool _isMine(Map<String, dynamic> msg) {
    return msg['remitente_tipo'] == widget.remitenteTipo &&
        msg['remitente_id'].toString() == widget.remitenteId;
  }

  String _horaLabel(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return 'Ahora';
    final match = RegExp(r'(\d{2}:\d{2})').allMatches(value);
    return match.isNotEmpty ? match.last.group(0)! : value;
  }

  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    BorderRadius radius = const BorderRadius.all(Radius.circular(28)),
    Color? color,
    Border? border,
  }) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.08),
            borderRadius: radius,
            border: border ?? Border.all(color: _glassBorder.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _glass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(
                    PhosphorIconsRegular.arrowLeft,
                    color: _textMain,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat de consulta',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Canal seguro para hablar con el profesional en tiempo real.',
                      style: GoogleFonts.manrope(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _accent.withOpacity(0.32)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'En linea',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  'Consulta #${widget.consultaId ?? '-'}',
                  style: GoogleFonts.manrope(
                    color: _textMain,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _glass(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          color: Colors.white.withOpacity(0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withOpacity(0.15),
                  border: Border.all(color: _accent.withOpacity(0.28)),
                ),
                child: Icon(
                  PhosphorIconsFill.chatCircleDots,
                  color: _accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'La conversación arranca acá',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mandá tu primer mensaje y mantené el seguimiento de la consulta sin salir de DocYa.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: _textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isMine = _isMine(msg);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMine ? 22 : 8),
      bottomRight: Radius.circular(isMine ? 8 : 22),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                isMine ? 'Vos' : 'Profesional',
                style: GoogleFonts.manrope(
                  color: isMine ? _accent : _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _glass(
                radius: radius,
                color: isMine
                    ? const Color(0xFF1CD3C3).withOpacity(0.95)
                    : Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: isMine
                      ? Colors.white.withOpacity(0.10)
                      : _glassBorder.withOpacity(0.48),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['mensaje']?.toString() ?? '',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.clock,
                          color: isMine
                              ? const Color(0xFF04343A).withOpacity(0.78)
                              : _textMuted.withOpacity(0.92),
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _horaLabel(msg['creado_en']),
                          style: GoogleFonts.manrope(
                            color: isMine
                                ? const Color(0xFF04343A).withOpacity(0.82)
                                : _textMuted.withOpacity(0.92),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _buildComposer() {
    return _glass(
      radius: BorderRadius.circular(30),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withOpacity(0.14),
            ),
            child: Icon(
              PhosphorIconsFill.chatCircleText,
              color: _accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribí un mensaje...',
                hintStyle: GoogleFonts.manrope(
                  color: _textMuted.withOpacity(0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, _accentSoft],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                PhosphorIconsFill.paperPlaneTilt,
                color: _bgBase,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _controller.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBase,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgBase, _bgSurface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_accent.withOpacity(0.20), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 220,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: _buildHeader(),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (_messages.isEmpty)
                          _buildEmptyState()
                        else
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                            itemCount: _messages.length,
                            itemBuilder: (_, index) =>
                                _buildBubble(_messages[index]),
                          ),
                        if (_showNewMsgIndicator)
                          Positioned(
                            right: 20,
                            bottom: 22,
                            child: GestureDetector(
                              onTap: () {
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                );
                                setState(() => _showNewMsgIndicator = false);
                              },
                              child: _glass(
                                radius: BorderRadius.circular(999),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                color: _accent.withOpacity(0.20),
                                border: Border.all(
                                  color: _accent.withOpacity(0.35),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIconsFill.arrowDown,
                                      color: _accent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Nuevo mensaje',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildComposer(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
