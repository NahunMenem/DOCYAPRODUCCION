import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TeleconsultaRoomScreen extends StatefulWidget {
  final int consultaId;
  final String pacienteUuid;
  final String roomUrl;

  const TeleconsultaRoomScreen({
    super.key,
    required this.consultaId,
    required this.pacienteUuid,
    required this.roomUrl,
  });

  @override
  State<TeleconsultaRoomScreen> createState() => _TeleconsultaRoomScreenState();
}

class _TeleconsultaRoomScreenState extends State<TeleconsultaRoomScreen> {
  static const Color _primary = Color(0xFF14B8A6);
  static const Color _bgBase = Color(0xFF06161D);
  static const Color _textMain = Color(0xFFE5F6F8);
  static const Color _textMuted = Color(0xFF9FB6BD);

  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setOnPermissionRequest((request) => request.grant())
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _requestPermissionsAndLoad();
  }

  Future<void> _requestPermissionsAndLoad() async {
    await [Permission.camera, Permission.microphone].request();
    if (mounted) {
      _controller.loadRequest(Uri.parse(widget.roomUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBase,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: _bgBase.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIconsFill.videoCamera,
                            color: _primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teleconsulta en curso',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  color: _textMain,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Consulta #${widget.consultaId}',
                                style: GoogleFonts.manrope(
                                  color: _textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            PhosphorIconsRegular.signOut,
                            size: 18,
                          ),
                          label: const Text('Salir'),
                          style: TextButton.styleFrom(
                            foregroundColor: _textMain,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: _bgBase,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _primary),
                      const SizedBox(height: 16),
                      Text(
                        'Conectando teleconsulta...',
                        style: GoogleFonts.manrope(
                          color: _textMain,
                          fontSize: 14,
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
    );
  }
}
