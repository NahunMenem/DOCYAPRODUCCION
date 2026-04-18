import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/payment_methods_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final String pacienteUuid;

  const PaymentMethodsScreen({super.key, required this.pacienteUuid});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  static const Color kPrimary = Color(0xFF14B8A6);
  final _service = PaymentMethodsService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDark ? Colors.white70 : const Color(0xFF5B6472);
  Color get _surfaceSoft =>
      _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2FBF9);
  Color get _borderColor =>
      _isDark ? Colors.white.withOpacity(0.12) : kPrimary.withOpacity(0.08);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.fetchMethods(widget.pacienteUuid);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    await _service.deleteMethod(id);
    await _load();
  }

  Widget _glass(Widget child, {EdgeInsets? padding, double radius = 24}) {
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
            border: Border.all(color: _borderColor),
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

  Widget _sectionLabel(String title, String helper) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: kPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  helper,
                  style: TextStyle(
                    color: _textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return _glass(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Pagos seguros',
              style: TextStyle(
                color: kPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tus metodos de pago, ordenados y listos para usar',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 27,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'DocYa guarda referencias seguras para acelerar futuros pagos dentro de la app, con una experiencia simple y protegida.',
            style: TextStyle(
              color: _textSecondary,
              height: 1.45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(Icons.credit_card_rounded,
                  '${_items.length} tarjetas guardadas'),
              _pill(Icons.lock_outline_rounded, 'Mercado Pago seguro'),
              _pill(Icons.bolt_rounded, 'Checkout mas rapido'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kPrimary),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return _glass(
      Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.credit_card_off_rounded,
              size: 34,
              color: kPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Todavia no hay tarjetas guardadas',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'La primera vez que pagues una consulta con tarjeta dentro de DocYa, podras guardar ese metodo para usarlo mas rapido la proxima vez.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardItem(Map<String, dynamic> item) {
    final brand = (item['brand'] ?? 'Tarjeta').toString();
    final lastFour = (item['last_four'] ?? '----').toString();
    final month = (item['expiration_month'] ?? '--').toString().padLeft(2, '0');
    final yearRaw = (item['expiration_year'] ?? '--').toString();
    final year =
        yearRaw.length >= 2 ? yearRaw.substring(yearRaw.length - 2) : yearRaw;

    return _glass(
      Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isDark
                      ? const [
                          Color(0xFF10343A),
                          Color(0xFF0B1F28),
                        ]
                      : const [
                          Color(0xFF14B8A6),
                          Color(0xFF0F9E91),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.credit_card_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        brand.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Metodo guardado',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '••••  ••••  ••••  $lastFour',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Vence',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$month/$year',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Referencia segura guardada para acelerar el checkout de futuras consultas.',
                    style: TextStyle(
                      color: _textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _delete(item['id'] as int),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.redAccent,
                  tooltip: 'Eliminar metodo',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isDark ? const Color(0xFF04151C) : const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Metodos de pago'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _textPrimary,
      ),
      body: Stack(
        children: [
          Positioned(
            right: -80,
            top: -50,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kPrimary.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else
            RefreshIndicator(
              onRefresh: _load,
              color: kPrimary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _hero(),
                  const SizedBox(height: 20),
                  _sectionLabel(
                    'Tarjetas guardadas',
                    'Administra las referencias seguras disponibles para tus proximos pagos.',
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    _emptyState()
                  else
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _cardItem(item),
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
