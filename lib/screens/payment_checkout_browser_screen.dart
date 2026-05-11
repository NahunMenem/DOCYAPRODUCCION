import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';

class PaymentCheckoutBrowserScreen extends StatefulWidget {
  final Uri url;
  final String title;
  final int? consultaId;

  const PaymentCheckoutBrowserScreen({
    super.key,
    required this.url,
    this.title = 'Pago seguro',
    this.consultaId,
  });

  @override
  State<PaymentCheckoutBrowserScreen> createState() =>
      _PaymentCheckoutBrowserScreenState();
}

class _PaymentCheckoutBrowserScreenState
    extends State<PaymentCheckoutBrowserScreen> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  Timer? _paymentPoller;
  bool _loading = true;
  bool _launchAttempted = false;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    _startPaymentPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchBrowser());
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _paymentPoller?.cancel();
    super.dispose();
  }

  void _startPaymentPolling() {
    if (widget.consultaId == null) return;
    _paymentPoller = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkBackendPaymentStatus();
    });
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
      'status': _normalizeStatus(uri.queryParameters['status'], uri.host),
      'consulta_id': uri.queryParameters['consulta_id'],
      'payment_id': uri.queryParameters['payment_id'],
    };

    _complete(payload);
  }

  Future<void> _checkBackendPaymentStatus() async {
    if (_completed || widget.consultaId == null) return;

    try {
      final response = await http.get(
        Uri.parse('$API_URL/consultas/${widget.consultaId}/estado'),
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mpStatus = (data['mp_status'] ?? '').toString().toLowerCase();
      final preauthorized = data['mp_preautorizado'] == true;
      final paymentId = data['payment_id']?.toString();

      if (preauthorized || _isApprovedStatus(mpStatus)) {
        _complete({
          'status': 'success',
          'consulta_id': widget.consultaId.toString(),
          'payment_id': paymentId,
        });
      }
    } catch (_) {
      // El navegador de pago sigue abierto; si falla un poll, probamos de nuevo.
    }
  }

  bool _isApprovedStatus(String status) {
    return status == 'success' ||
        status == 'approved' ||
        status == 'authorized' ||
        status == 'preautorizado' ||
        status == 'capturado' ||
        status == 'captured';
  }

  String _normalizeStatus(String? rawStatus, String host) {
    final status = (rawStatus ?? '').toLowerCase().trim();
    if (_isApprovedStatus(status)) return 'success';
    if (status == 'pending' || status == 'in_process') return 'pending';
    if (status == 'cancelled' || status == 'cancelled_by_user') {
      return 'cancelled';
    }
    if (status == 'failed' || status == 'failure' || status == 'rejected') {
      return 'failed';
    }

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

  void _complete(Map<String, dynamic> payload) {
    if (_completed || !mounted) return;
    _completed = true;
    _paymentPoller?.cancel();
    unawaited(closeInAppWebView());
    Navigator.of(context).pop(payload);
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
    _complete({'status': 'cancelled'});
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
