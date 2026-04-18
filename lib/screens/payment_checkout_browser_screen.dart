import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentCheckoutBrowserScreen extends StatefulWidget {
  final Uri url;
  final String title;

  const PaymentCheckoutBrowserScreen({
    super.key,
    required this.url,
    this.title = 'Pago seguro',
  });

  @override
  State<PaymentCheckoutBrowserScreen> createState() =>
      _PaymentCheckoutBrowserScreenState();
}

class _PaymentCheckoutBrowserScreenState
    extends State<PaymentCheckoutBrowserScreen> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  bool _loading = true;
  bool _launchAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchBrowser());
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _launchBrowser() async {
    if (_launchAttempted) return;
    _launchAttempted = true;

    try {
      final launched = await launchUrl(
        widget.url,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched && mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo abrir el navegador seguro de pago.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo abrir el flujo de pago.';
      });
    }
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme != 'docya') return;

    final isPaymentResult = uri.host == 'payment_result' ||
        uri.host == 'pago_exitoso' ||
        uri.host == 'pago_fallido' ||
        uri.host == 'pago_pendiente';

    if (!isPaymentResult) return;

    final payload = <String, dynamic>{
      'status': uri.queryParameters['status'] ?? _mapLegacyStatus(uri.host),
      'consulta_id': uri.queryParameters['consulta_id'],
      'payment_id': uri.queryParameters['payment_id'],
    };

    if (!mounted) return;
    Navigator.of(context).pop(payload);
  }

  String _mapLegacyStatus(String host) {
    switch (host) {
      case 'pago_exitoso':
        return 'success';
      case 'pago_fallido':
        return 'failed';
      case 'pago_pendiente':
        return 'pending';
      default:
        return 'unknown';
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _launchAttempted = false;
    });
    _launchBrowser();
  }

  void _cancel() {
    Navigator.of(context).pop({'status': 'cancelled'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Abriendo pago seguro...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Vas a autorizar la consulta en un navegador seguro dentro de DocYa y después volvés automáticamente.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancelar'),
                ),
              ] else ...[
                Icon(
                  _error == null
                      ? Icons.open_in_browser_rounded
                      : Icons.error_outline_rounded,
                  size: 56,
                  color: _error == null
                      ? Theme.of(context).colorScheme.primary
                      : Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Si no se abrió el flujo, tocá reintentar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _retry,
                  child: const Text('Reintentar'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
