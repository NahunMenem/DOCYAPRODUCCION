import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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

  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _configureAndroidPermissions();
    _requestPermissionsAndLoad();
  }

  void _configureAndroidPermissions() {
    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setMediaPlaybackRequiresUserGesture(false);
      platformController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }
  }

  Future<void> _requestPermissionsAndLoad() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    if (!cameraGranted || !micGranted) {
      await openAppSettings();
      return;
    }
    if (mounted) {
      _controller.loadRequest(Uri.parse(widget.roomUrl));
    }
  }

  Future<bool> _confirmarSalida() async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black87,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF102730),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(PhosphorIconsRegular.videoCamera, color: _primary, size: 32),
            title: Text(
              '¿Salir de la videollamada?',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: _textMain,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            content: Text(
              'Si salís ahora, la teleconsulta seguirá activa pero vas a dejar la llamada.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFF9FB6BD),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
                child: const Text('Continuar en llamada'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFf87171),
                  textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
                child: const Text('Salir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final salir = await _confirmarSalida();
        if (salir && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _bgBase,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: WebViewWidget(controller: _controller)),
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
        ),
      ),
    );
  }
}
