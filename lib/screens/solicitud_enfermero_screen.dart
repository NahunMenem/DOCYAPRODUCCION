import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../globals.dart';
import '../services/auth_service.dart';
import '../services/mercado_pago_native_service.dart';
import '../services/payment_methods_service.dart';
import '../widgets/docya_snackbar.dart';
import 'buscando_medico_screen.dart';
import 'complete_profile_screen.dart';
import 'payment_checkout_browser_screen.dart';

class SolicitudEnfermeroScreen extends StatefulWidget {
  final String direccion;
  final LatLng ubicacion;

  const SolicitudEnfermeroScreen({
    super.key,
    required this.direccion,
    required this.ubicacion,
  });

  @override
  State<SolicitudEnfermeroScreen> createState() =>
      _SolicitudEnfermeroScreenState();
}

class _NursingService {
  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
  final Color color;
  final List<String> includes;
  final List<String> notes;

  const _NursingService({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
    required this.color,
    required this.includes,
    required this.notes,
  });
}

class _SolicitudEnfermeroScreenState extends State<SolicitudEnfermeroScreen>
    with WidgetsBindingObserver {
  final motivoCtrl = TextEditingController();

  bool aceptaConsentimiento = false;
  bool pagando = false;
  String metodoPago = "tarjeta";
  final _paymentService = PaymentMethodsService();
  final _authService = AuthService();
  final _nativePaymentService = MercadoPagoNativeService();
  List<Map<String, dynamic>> _savedMethods = [];
  Map<String, dynamic>? _selectedSavedMethod;
  bool _loadingSavedMethods = false;

  int? consultaPreviaId;
  String pagoPreautorizadoGlobal = "";
  String? _paymentId;
  bool pagoConfirmadoUnaVez = false;
  int? _precioActual;
  String _descripcionPrecio = "";
  bool _cargandoTarifa = true;
  int? _selectedServiceIndex;
  String? _autoMotivoServicio;

  static const List<_NursingService> _services = [
    _NursingService(
      title: "Aplicacion de inyectables IM/SC",
      subtitle:
          "Aplicacion de medicamentos por via intramuscular o subcutanea.",
      duration: "30-40 min",
      icon: Icons.vaccines_rounded,
      color: Color(0xFF18B7AD),
      includes: [
        "Aplicacion de medicacion IM o SC",
        "Materiales descartables basicos",
        "Traslado del profesional a tu domicilio",
        "Reporte del servicio en tu historial",
      ],
      notes: [
        "El paciente debe contar con la medicacion y la indicacion medica.",
        "Si el profesional necesita materiales adicionales, el precio puede variar.",
      ],
    ),
    _NursingService(
      title: "Curaciones simples",
      subtitle: "Limpieza y curacion de heridas leves.",
      duration: "30-45 min",
      icon: Icons.healing_rounded,
      color: Color(0xFF4CBF7A),
      includes: [
        "Limpieza de herida leve",
        "Curacion con materiales basicos",
        "Control visual de la zona",
        "Registro del servicio en tu historial",
      ],
      notes: [
        "No reemplaza una guardia si hay sangrado abundante, fiebre o dolor intenso.",
        "Puede requerir materiales adicionales segun la herida.",
      ],
    ),
    _NursingService(
      title: "Control de presion",
      subtitle: "Medicion y control de presion arterial.",
      duration: "15-20 min",
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFF6C63FF),
      includes: [
        "Toma de presion arterial",
        "Registro de valores",
        "Orientacion basica segun resultado",
        "Reporte del control en tu historial",
      ],
      notes: [
        "Si hay dolor de pecho, falta de aire o desmayo, llama al 107 o 911.",
      ],
    ),
    _NursingService(
      title: "Control de glucemia",
      subtitle: "Medicion de niveles de glucosa en sangre.",
      duration: "15-20 min",
      icon: Icons.bloodtype_rounded,
      color: Color(0xFFE4A72D),
      includes: [
        "Medicion de glucemia capilar",
        "Registro del valor",
        "Orientacion basica segun resultado",
        "Reporte del control en tu historial",
      ],
      notes: [
        "Si hay confusion, perdida de conocimiento o mal estado general, llama al 107 o 911.",
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarTarifa();
    _cargarTarjetasGuardadas();
    _verificarPerfilCompleto();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarPagoBackend() async {
    if (consultaPreviaId == null) return;

    try {
      final res = await http.get(
        Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/$consultaPreviaId/estado",
        ),
      );

      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final preaut = data["mp_preautorizado"] == true;
      _paymentId = data["payment_id"]?.toString();

      setState(() {
        pagoPreautorizadoGlobal = preaut ? "preautorizado" : "";
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarPagoBackend();
    }
  }

  Future<void> _verificarPerfilCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    final perfilCompleto = prefs.getBool("perfilCompleto") ?? false;

    if (!perfilCompleto && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CompleteProfileScreen(forceProfile: true),
        ),
      );
    }
  }

  int _parseMonto(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _cargarTarifa() async {
    try {
      final res = await http.get(
        Uri.parse('$API_URL/tarifas/consulta-enfermero'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _precioActual = _parseMonto(data['monto']);
          _descripcionPrecio = (data['descripcion'] ?? '').toString();
          _cargandoTarifa = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _cargandoTarifa = false;
    });
  }

  Future<void> _cargarTarjetasGuardadas() async {
    setState(() => _loadingSavedMethods = true);
    try {
      final methods = await _paymentService.fetchMethods(pacienteUuidGlobal);
      if (!mounted) return;
      setState(() {
        _savedMethods = methods;
        _selectedSavedMethod = methods.isNotEmpty ? methods.first : null;
        _loadingSavedMethods = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSavedMethods = false);
    }
  }

  String _savedCardExpiration(Map<String, dynamic> item) {
    final month = item['expiration_month']?.toString().padLeft(2, '0') ?? '--';
    final yearRaw = item['expiration_year']?.toString() ?? '--';
    final year =
        yearRaw.length >= 2 ? yearRaw.substring(yearRaw.length - 2) : yearRaw;
    return '$month/$year';
  }

  String _savedCardLabel(Map<String, dynamic> item) {
    final brand = (item["brand"] ?? "Tarjeta").toString();
    final lastFour = (item["last_four"] ?? "----").toString();
    return '$brand **** $lastFour';
  }

  bool _canReuseSavedMethod(Map<String, dynamic>? item) {
    if (item == null) return false;
    final cardId = item["mp_card_id"]?.toString() ?? "";
    final customerId = item["mp_customer_id"]?.toString() ?? "";
    final paymentMethodId = item["payment_method_id"]?.toString() ?? "";
    final issuerId = item["issuer_id"]?.toString() ?? "";
    final reusable = item["reusable"] == true;
    return reusable ||
        (cardId.isNotEmpty &&
            customerId.isNotEmpty &&
            paymentMethodId.isNotEmpty &&
            issuerId.isNotEmpty);
  }

  int _calcularPrecio() {
    if (_precioActual != null) {
      return _precioActual!;
    }
    final argentina = tz.getLocation('America/Argentina/Buenos_Aires');
    final ahora = tz.TZDateTime.now(argentina);
    final h = ahora.hour;

    return (h >= 22 || h < 6) ? 30000 : 20000;
  }

  String _mensajePrecio(int precio) {
    if (_descripcionPrecio.isNotEmpty) {
      return _descripcionPrecio;
    }
    return precio == 30000
        ? "Tarifa nocturna (22:00-06:00). Incluye atención profesional de enfermería."
        : "Incluye atención profesional de enfermería a domicilio.";
  }

  Future<void> _pagar() async {
    final precio = _calcularPrecio();

    if (motivoCtrl.text.trim().isEmpty) {
      _toast("Escribi el motivo de la consulta");
      return;
    }
    if (!aceptaConsentimiento) {
      _toast("Debes aceptar la declaracion jurada");
      return;
    }

    setState(() => pagando = true);

    try {
      final previa = await http.post(
        Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/crear_previa",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "paciente_uuid": pacienteUuidGlobal,
          "motivo": motivoCtrl.text.trim(),
          "direccion": widget.direccion,
          "lat": widget.ubicacion.latitude,
          "lng": widget.ubicacion.longitude,
          "tipo": "enfermero"
        }),
      );

      if (previa.statusCode != 200) {
        _toast("Error creando consulta");
        setState(() => pagando = false);
        return;
      }

      final previaData = jsonDecode(previa.body);
      consultaPreviaId = previaData["consulta_id"];
      final motivoPago = motivoCtrl.text.trim().isEmpty
          ? "Atencion de enfermeria DocYa"
          : motivoCtrl.text.trim();

      if (Platform.isAndroid) {
        final config = await _paymentService.fetchPublicConfig();
        final profile =
            await _authService.fetchUserProfile(pacienteUuidGlobal) ?? {};
        final wantsSavedCard = _selectedSavedMethod != null;
        final useSavedCard = _canReuseSavedMethod(_selectedSavedMethod);

        if (wantsSavedCard && !useSavedCard) {
          _toast(
            "Esta tarjeta guardada necesita revalidarse. Elegi otra o usa una tarjeta nueva.",
          );
          setState(() => pagando = false);
          return;
        }

        final nativeResult = useSavedCard
            ? await _nativePaymentService.collectSavedCardToken(
                publicKey: (config["public_key"] ?? "").toString(),
                countryCode: (config["country_code"] ?? "ARG").toString(),
                title: "Autoriza tu atencion",
                description:
                    "DocYa reserva el pago y solo lo captura cuando un enfermero acepta tu pedido.",
                payerEmail: pacienteEmailGlobal,
                cardholderName: (_selectedSavedMethod!["holder_name"] ??
                        profile["full_name"] ??
                        "Titular")
                    .toString(),
                identificationType: (profile["tipo_documento"] ?? "DNI")
                    .toString()
                    .toUpperCase(),
                identificationNumber:
                    (profile["numero_documento"] ?? "").toString(),
                savedCardId: _selectedSavedMethod!["mp_card_id"].toString(),
                savedCardBrand:
                    (_selectedSavedMethod!["brand"] ?? "Tarjeta").toString(),
                savedCardLastFour:
                    (_selectedSavedMethod!["last_four"] ?? "----").toString(),
                savedCardExpiration:
                    _savedCardExpiration(_selectedSavedMethod!),
                paymentMethodId:
                    _selectedSavedMethod!["payment_method_id"]?.toString(),
                issuerId: _selectedSavedMethod!["issuer_id"]?.toString(),
              )
            : await _nativePaymentService.collectCardToken(
                publicKey: (config["public_key"] ?? "").toString(),
                countryCode: (config["country_code"] ?? "ARG").toString(),
                amount: precio.toDouble(),
                title: "Autoriza tu atencion",
                description:
                    "DocYa reserva el pago y solo lo captura cuando un enfermero acepta tu pedido.",
                payerEmail: pacienteEmailGlobal,
                cardholderName: (profile["full_name"] ?? "Titular").toString(),
                identificationType: (profile["tipo_documento"] ?? "DNI")
                    .toString()
                    .toUpperCase(),
                identificationNumber:
                    (profile["numero_documento"] ?? "").toString(),
              );

        final status = nativeResult["status"]?.toString() ?? "cancelled";
        if (status != "success") {
          final nativeError = nativeResult["error"]?.toString();
          _toast(
            nativeError?.isNotEmpty == true
                ? nativeError!
                : status == "cancelled"
                    ? "Autorizacion cancelada"
                    : "No se pudo preparar la tarjeta",
          );
          setState(() => pagando = false);
          return;
        }

        final authorization = await _paymentService.authorizeNativePayment(
          consultaId: consultaPreviaId!,
          pacienteUuid: pacienteUuidGlobal,
          monto: precio.toDouble(),
          motivo: motivoPago,
          tipo: "enfermero",
          token: (nativeResult["token"] ?? "").toString(),
          paymentMethodId: useSavedCard
              ? _selectedSavedMethod!["payment_method_id"].toString()
              : (nativeResult["payment_method_id"] ?? "").toString(),
          issuerId: useSavedCard
              ? _selectedSavedMethod!["issuer_id"]?.toString()
              : nativeResult["issuer_id"]?.toString(),
          payerEmail:
              (nativeResult["payer_email"] ?? pacienteEmailGlobal).toString(),
          identificationType: nativeResult["identification_type"]?.toString(),
          identificationNumber:
              nativeResult["identification_number"]?.toString(),
          saveCard: nativeResult["save_card"] == true,
        );

        if (authorization["authorized"] != true) {
          _toast("No se pudo autorizar la tarjeta");
          setState(() => pagando = false);
          return;
        }

        _paymentId = authorization["payment_id"]?.toString();
        setState(() {
          pagoPreautorizadoGlobal = "preautorizado";
        });
        setState(() => pagando = false);
        await _solicitar();
        return;
      }

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutBrowserScreen(
            title: "Autorización segura",
            url: _paymentService.buildEmbeddedPaymentUrl(
              pacienteUuid: pacienteUuidGlobal,
              consultaId: consultaPreviaId!,
              monto: precio.toDouble(),
              tipo: "enfermero",
              motivo: motivoCtrl.text.trim().isEmpty
                  ? "Atención de enfermería DocYa"
                  : motivoCtrl.text.trim(),
            ),
          ),
        ),
      );

      final status = result?["status"]?.toString() ?? "cancelled";
      if (status != "success") {
        if (status == "cancelled") {
          _toast("Autorización cancelada");
        } else if (status == "pending") {
          _toast("El pago quedó pendiente de confirmación");
        } else {
          _toast("Error iniciando pago");
        }
        setState(() => pagando = false);
        return;
      }

      _paymentId = result!["payment_id"]?.toString();
      setState(() {
        pagoPreautorizadoGlobal = "preautorizado";
      });
      setState(() => pagando = false);
      await _solicitar();
      return;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      _toast(message.isEmpty ? "Error iniciando pago" : message);
    }

    setState(() => pagando = false);
  }

  Future<void> _solicitar() async {
    if (motivoCtrl.text.trim().isEmpty) {
      _toast("Escribí el motivo de la consulta");
      return;
    }

    if (!aceptaConsentimiento) {
      _toast("Debes aceptar la declaración jurada");
      return;
    }

    if (metodoPago == "tarjeta" && pagoPreautorizadoGlobal != "preautorizado") {
      _toast("Debes completar el pago primero");
      return;
    }

    final body = jsonEncode({
      "consulta_id": consultaPreviaId,
      "paciente_uuid": pacienteUuidGlobal,
      "motivo": motivoCtrl.text.trim(),
      "direccion": widget.direccion,
      "lat": widget.ubicacion.latitude,
      "lng": widget.ubicacion.longitude,
      "metodo_pago": metodoPago == "saldo_mp" ? "saldo_mp" : metodoPago,
      "payment_id": _paymentId ?? "",
      "tipo": "enfermero",
    });

    try {
      final res = await http.post(
        Uri.parse(
          "https://docya-railway-production.up.railway.app/consultas/solicitar",
        ),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (res.statusCode != 200) {
        _toast("No se pudo solicitar enfermero");
        return;
      }

      final data = jsonDecode(res.body);
      final estado = data["estado"]?.toString();
      if (estado == "cancelada" ||
          estado == "pendiente_de_refund" ||
          estado == "sin_profesionales" ||
          estado == "sin_medicos") {
        _toast(
          (data["mensaje"] ?? "No encontramos profesionales disponibles.")
              .toString(),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          "consulta_activa_id", data["consulta_id"].toString());

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuscandoMedicoScreen(
            direccion: widget.direccion,
            ubicacion: widget.ubicacion,
            motivo: motivoCtrl.text.trim(),
            consultaId: data["consulta_id"],
            pacienteUuid: pacienteUuidGlobal,
            paymentId: _paymentId ?? "",
            tipoProfesional: "enfermero",
          ),
        ),
      );
    } catch (_) {
      _toast("Error de conexión");
    }
  }

  void _toast(String m) {
    DocYaSnackbar.show(
      context,
      title: "Aviso",
      message: m,
      type: SnackType.warning,
    );
  }

  Widget _saldoMpInfoRows(bool isDark) {
    final items = [
      (
        Icons.hourglass_empty_rounded,
        'No se cobra ahora',
        'El monto queda reservado en tu cuenta MP pero no debitado.'
      ),
      (
        Icons.check_circle_outline_rounded,
        'Se cobra solo si un enfermero acepta',
        'En el momento exacto que alguien acepta tu consulta.'
      ),
      (
        Icons.replay_rounded,
        'Si nadie acepta o cancelas',
        'El reintegro es casi instantaneo — vuelve a tu saldo MP en minutos.'
      ),
    ];
    return Column(
      children: items.map((item) {
        final (icon, titulo, detalle) = item;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF00BCFF)),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '$titulo. ',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: detalle,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _botonSaldoMp() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ElevatedButton.icon(
        onPressed: pagando ? null : _pagarConSaldoMp,
        icon: pagando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.account_balance_wallet_rounded),
        label:
            Text(pagando ? 'Procesando...' : 'Pagar con saldo MP y solicitar'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          backgroundColor: const Color(0xFF00BCFF),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _pagarConSaldoMp() async {
    if (motivoCtrl.text.trim().isEmpty || !aceptaConsentimiento) {
      _toast('Completá el motivo y aceptá la declaración jurada.');
      return;
    }
    setState(() => pagando = true);
    try {
      final precio = _calcularPrecio();
      final previa = await http.post(
        Uri.parse('$API_URL/consultas/crear_previa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paciente_uuid': pacienteUuidGlobal,
          'motivo': motivoCtrl.text.trim(),
          'direccion': widget.direccion,
          'lat': widget.ubicacion.latitude,
          'lng': widget.ubicacion.longitude,
          'tipo': 'enfermero',
        }),
      );
      if (previa.statusCode != 200) {
        _toast('No se pudo preparar la consulta.');
        setState(() => pagando = false);
        return;
      }
      consultaPreviaId = jsonDecode(previa.body)['consulta_id'];

      final prefRes = await http.post(
        Uri.parse('$API_URL/pagos/saldo-mp/preferencia'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paciente_uuid': pacienteUuidGlobal,
          'consulta_id': consultaPreviaId,
          'monto': precio.toDouble(),
          'motivo': motivoCtrl.text.trim().isEmpty
              ? 'Atención de enfermería DocYa'
              : motivoCtrl.text.trim(),
        }),
      );
      if (prefRes.statusCode != 200) {
        final err = jsonDecode(prefRes.body);
        _toast((err['detail']?['message'] ??
                err['message'] ??
                'Error al iniciar el pago')
            .toString());
        setState(() => pagando = false);
        return;
      }
      final initPoint =
          jsonDecode(prefRes.body)['init_point']?.toString() ?? '';
      if (initPoint.isEmpty) {
        _toast('No se pudo obtener la URL de pago.');
        setState(() => pagando = false);
        return;
      }

      if (!mounted) return;
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutBrowserScreen(
            title: 'Pagar con Mercado Pago',
            url: Uri.parse(initPoint),
          ),
        ),
      );

      final status = result?['status']?.toString() ?? 'cancelled';
      if (status != 'success') {
        _toast(status == 'cancelled'
            ? 'Pago cancelado'
            : 'No se pudo completar el pago');
        setState(() => pagando = false);
        return;
      }
      _paymentId = result!['payment_id']?.toString();
      pagoPreautorizadoGlobal = 'preautorizado';
      setState(() => pagando = false);
      await _solicitar();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
      setState(() => pagando = false);
    }
  }

  Widget _glassCard(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : const Color(0xFF14B8A6).withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.18)
                : const Color(0xFF14B8A6).withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _header(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0EA896),
                    Color(0xFF2DD4BF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withOpacity(0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Atención de enfermería",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "Solicitud de enfermero",
            style: TextStyle(
              color: Color(0xFF14B8A6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Completás el motivo, autorizás el pago y DocYa empieza a buscar un enfermero cercano. Solo capturamos el cobro final cuando un profesional acepta tu pedido.",
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _cardMotivo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title("Motivo de la consulta", isDark),
        const SizedBox(height: 12),
        TextField(
          controller: motivoCtrl,
          maxLines: 4,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText:
                "Describí tus síntomas, necesidad o tipo de asistencia requerida...",
            hintStyle:
                TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFF7FBFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white30
                    : const Color(0xFF14B8A6).withOpacity(0.10),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white24
                    : const Color(0xFF14B8A6).withOpacity(0.10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: aceptaConsentimiento,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() => aceptaConsentimiento = v!),
            ),
            Expanded(
              child: Text(
                "Declaro haber respondido honestamente el triage previo.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardPagoDigital(int precio, bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;
    final esSaldoMp = metodoPago == "saldo_mp";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _precioCard(precio, isDark),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _paymentTab(
                  value: "tarjeta",
                  icon: Icons.credit_card_rounded,
                  label: "Tarjeta de crédito",
                  isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(
              child: _paymentTab(
                  value: "saldo_mp",
                  icon: Icons.account_balance_wallet_rounded,
                  label: "Saldo Mercado Pago",
                  isDark: isDark)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.lock_outline_rounded, color: primary, size: 18),
          const SizedBox(width: 8),
          Text("Pago con preautorizacion",
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        _pagoInfoRow(
            Icons.hourglass_empty_rounded,
            "No se cobra ahora",
            esSaldoMp
                ? "Con saldo MP se paga al confirmar y se reintegra si nadie acepta."
                : "El monto queda reservado en tu tarjeta pero no debitado.",
            isDark),
        const SizedBox(height: 8),
        _pagoInfoRow(
            Icons.check_circle_outline_rounded,
            "Se cobra solo si un enfermero acepta",
            "En el momento exacto que alguien acepta tu consulta.",
            isDark),
        const SizedBox(height: 8),
        _pagoInfoRow(
            Icons.replay_rounded,
            "Si nadie acepta o cancelas",
            esSaldoMp
                ? "El reintegro es casi instantaneo — vuelve a tu saldo MP en minutos."
                : "La reserva se libera sola en menos de 5 minutos. No perdes nada.",
            isDark),
        if (metodoPago == "tarjeta") ...[
          const SizedBox(height: 16),
          _savedCardsSection(isDark),
        ],
      ],
    );
  }

  Widget _cardEfectivoEnfermero(bool isDark) {
    final selected = metodoPago == "efectivo";
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => metodoPago = "efectivo"),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? primary.withOpacity(0.14)
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03)),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.attach_money_rounded,
                color: selected
                    ? primary
                    : (isDark ? Colors.white54 : Colors.black45)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Efectivo / Transferencia",
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                  "Pago directo al enfermero cuando llega o por transferencia.",
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12.5,
                      height: 1.3)),
            ]),
          ),
          Radio<String>(
            value: "efectivo",
            groupValue: metodoPago,
            onChanged: (v) => setState(() => metodoPago = v!),
            activeColor: primary,
          ),
        ],
      ),
    );
  }

  Widget _paymentTab(
      {required String value,
      required IconData icon,
      required String label,
      required bool isDark}) {
    final selected = metodoPago == value;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => metodoPago = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withOpacity(0.14)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primary.withOpacity(0.55)
                : (isDark
                    ? Colors.white.withOpacity(0.09)
                    : Colors.black.withOpacity(0.07)),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? primary
                    : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 6),
            Flexible(
                child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? primary
                    : (isDark ? Colors.white54 : Colors.black45),
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                height: 1.2,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _pagoInfoRow(
      IconData icon, String titulo, String detalle, bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: '$titulo. ',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5)),
              TextSpan(
                  text: detalle,
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 12.5,
                      height: 1.35)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _precioCard(int precio, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white24
              : const Color(0xFF14B8A6).withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.monitor_heart_rounded,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "\$$precio",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _mensajePrecio(precio),
                  style: TextStyle(
                    height: 1.3,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedCardsSection(bool isDark) {
    if (_loadingSavedMethods) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_savedMethods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF7FBFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Text(
          "Todavia no tenes tarjetas reutilizables. La primera vez autorizas normal y despues podes usar una guardada con solo el codigo de seguridad.",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.35,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tarjetas guardadas",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Elegí una tarjeta guardada para validar solo el CVV. Si preferís otra, podés usar una tarjeta nueva.",
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedSavedMethod = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedSavedMethod == null
                    ? const Color(0xFF14B8A6).withOpacity(0.12)
                    : (isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF7FBFB)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedSavedMethod == null
                      ? const Color(0xFF14B8A6)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: _selectedSavedMethod == null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_card_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Usar una tarjeta nueva",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Ingresá los datos completos. Si querés, después la dejamos lista para reutilizarla.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ..._savedMethods.map((item) {
          final selected = _selectedSavedMethod?["id"] == item["id"];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSavedMethod = item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF009EE3).withOpacity(0.12)
                      : (isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFF7FBFB)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF009EE3)
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.credit_card_rounded,
                      color: Color(0xFF009EE3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _savedCardLabel(item),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vence ${_savedCardExpiration(item)} · Ya no tenés que escribir el número completo',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _paymentOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = metodoPago == value;

    return GestureDetector(
      onTap: () => setState(() => metodoPago = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.14)
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFF7FBFB)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected ? color : (isDark ? Colors.white24 : Colors.black26),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : Colors.white38,
                  width: 2,
                ),
              ),
              child: selected
                  ? Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonMP() {
    return GestureDetector(
      onTap: pagando ? null : _pagar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF009EE3),
              Color(0xFF18B4F7),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF009EE3).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: pagando
              ? const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      "Autorizar y solicitar enfermero",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _warningMP(bool isDark) {
    if (metodoPago != "tarjeta") return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF7FBFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white24
                : const Color(0xFF14B8A6).withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Este pago es una preautorización. El cargo solo se realiza cuando un profesional acepta tu consulta. Si no se asigna ningún enfermero, no se realizará ningún débito.",
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonSolicitar(bool isDark) {
    final ready =
        metodoPago == "efectivo" || pagoPreautorizadoGlobal == "preautorizado";

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: ready ? 1 : 0.6,
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ready
                  ? const [
                      Color(0xFF0EA896),
                      Color(0xFF14B8A6),
                      Color(0xFF2DD4BF),
                    ]
                  : [
                      Colors.grey.shade500,
                      Colors.grey.shade400,
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withOpacity(0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: ready ? _solicitar : null,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Solicitar enfermero",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String t, bool isDark) {
    return Text(
      t,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  String _formatPrecio(int precio) {
    if (_cargandoTarifa) return "...";
    final value = precio.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
    return "\$$value";
  }

  Color _pageBg(bool isDark) =>
      isDark ? const Color(0xFF061D24) : const Color(0xFFF8FBFD);

  Color _surface(bool isDark) =>
      isDark ? const Color(0xFF0D2B34) : Colors.white;

  Color _textMain(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF071238);

  Color _textSoft(bool isDark) =>
      isDark ? Colors.white70 : const Color(0xFF536078);

  void _selectService(int index) {
    final service = _services[index];
    setState(() {
      _selectedServiceIndex = index;
      if (motivoCtrl.text.trim().isEmpty ||
          motivoCtrl.text.trim() == _autoMotivoServicio) {
        motivoCtrl.text = service.title;
        _autoMotivoServicio = service.title;
      }
    });
  }

  Widget _logoHeader(bool isDark) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _surface(isDark),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: _textMain(isDark),
            onPressed: () {
              if (_selectedServiceIndex != null) {
                setState(() => _selectedServiceIndex = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        const Spacer(),
        Image.asset(
          isDark ? "assets/logoblanco.png" : "assets/logonegro.png",
          height: 48,
        ),
        const Spacer(),
        const SizedBox(width: 46),
      ],
    );
  }

  Widget _heroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE9EEF4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF18B7AD).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Color(0xFF08786F),
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enfermeria basica",
                      style: TextStyle(
                        color: _textMain(isDark),
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Rapido • A domicilio",
                      style: TextStyle(
                        color: Color(0xFF07877E),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            "Servicios simples para tu tranquilidad, con enfermeros matriculados y evaluados por DocYa.",
            style: TextStyle(
              color: _textSoft(isDark),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18B7AD).withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF08786F),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Profesionales verificados y precio actualizado desde DocYa.",
                    style: TextStyle(
                      color: _textMain(isDark),
                      height: 1.3,
                      fontWeight: FontWeight.w700,
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

  Widget _serviceTile(
    _NursingService service,
    int index,
    int precio,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _selectService(index),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface(isDark),
          border: Border(
            bottom: index == _services.length - 1
                ? BorderSide.none
                : BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE8EDF3),
                  ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: service.color.withOpacity(isDark ? 0.22 : 0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(service.icon, color: service.color, size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: TextStyle(
                      color: _textMain(isDark),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service.subtitle,
                    style: TextStyle(
                      color: _textSoft(isDark),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrecio(precio),
                  style: const TextStyle(
                    color: Color(0xFF07877E),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  service.duration,
                  style: TextStyle(
                    color: _textSoft(isDark),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: _textMain(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _serviceList(int precio, bool isDark) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE9EEF4),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _services.length; i++)
            _serviceTile(_services[i], i, precio, isDark),
        ],
      ),
    );
  }

  Widget _detailHeader(_NursingService service, int precio, bool isDark) {
    return Column(
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: service.color.withOpacity(isDark ? 0.20 : 0.12),
          ),
          child: Icon(service.icon, color: service.color, size: 88),
        ),
        const SizedBox(height: 20),
        Text(
          service.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textMain(isDark),
            fontSize: 27,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          service.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSoft(isDark),
            fontSize: 16,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _detailInfoCard(service, precio, isDark),
      ],
    );
  }

  Widget _detailInfoCard(_NursingService service, int precio, bool isDark) {
    final rows = [
      (Icons.schedule_rounded, "Duracion estimada", service.duration),
      (Icons.sell_outlined, "Precio del servicio", _formatPrecio(precio)),
      (
        Icons.medical_services_outlined,
        "Profesional",
        "Enfermero/a matriculado/a"
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5EAF1),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i == rows.length - 1
                      ? BorderSide.none
                      : BorderSide(
                          color:
                              isDark ? Colors.white10 : const Color(0xFFE8EDF3),
                        ),
                ),
              ),
              child: Row(
                children: [
                  Icon(rows[i].$1, color: _textMain(isDark), size: 28),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].$2,
                          style: TextStyle(
                            color: _textSoft(isDark),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rows[i].$3,
                          style: TextStyle(
                            color: _textMain(isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _includedSection(_NursingService service, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "¿Que incluye?",
          style: TextStyle(
            color: _textMain(isDark),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        ...service.includes.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D9488),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: _textMain(isDark),
                      fontSize: 14.5,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _notesCard(_NursingService service, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE0EAF8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF3182BD)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tene en cuenta",
                  style: TextStyle(
                    color: _textMain(isDark),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...service.notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "• $note",
                      style: TextStyle(
                        color: _textMain(isDark),
                        height: 1.35,
                        fontSize: 13.5,
                      ),
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

  Widget _readyItems(bool isDark) {
    final items = [
      (Icons.medication_liquid_rounded, "Medicamento", "Lo tengo"),
      (Icons.assignment_rounded, "Indicacion medica", "La tengo"),
      (Icons.medical_information_rounded, "Materiales", "No los tengo"),
    ];

    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: _surface(isDark),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE5EAF1),
                ),
              ),
              child: Column(
                children: [
                  Icon(item.$1, color: const Color(0xFF0E5B8E), size: 28),
                  const SizedBox(height: 8),
                  Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMain(isDark),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF07877E),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item != items.last) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildServiceListPage(bool isDark, int precio) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _logoHeader(isDark),
          const SizedBox(height: 28),
          _heroCard(isDark),
          const SizedBox(height: 26),
          Text(
            "Elegi el servicio que necesitas",
            style: TextStyle(
              color: _textMain(isDark),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _serviceList(precio, isDark),
        ],
      ),
    );
  }

  Widget _buildServiceDetailPage(bool isDark, int precio) {
    final service = _services[_selectedServiceIndex ?? 0];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _logoHeader(isDark),
          const SizedBox(height: 24),
          _detailHeader(service, precio, isDark),
          const SizedBox(height: 26),
          _includedSection(service, isDark),
          const SizedBox(height: 18),
          _notesCard(service, isDark),
          const SizedBox(height: 24),
          Text(
            "¿Ya tenes todo listo?",
            style: TextStyle(
              color: _textMain(isDark),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          _readyItems(isDark),
          const SizedBox(height: 20),
          _glassCard(_cardMotivo(isDark)),
          _glassCard(_cardPagoDigital(precio, isDark)),
          if (metodoPago == "tarjeta") _botonMP(),
          if (metodoPago == "saldo_mp") _botonSaldoMp(),
          _glassCard(_cardEfectivoEnfermero(isDark)),
          if (metodoPago == "efectivo") ...[
            const SizedBox(height: 2),
            _botonSolicitar(isDark),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final precio = _calcularPrecio();

    return Scaffold(
      backgroundColor: _pageBg(isDark),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF04151C),
                        Color(0xFF0C2530),
                        Color(0xFF133743),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFF7FBFB),
                        Colors.white,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
          ),
          if (isDark) ...[
            Positioned(
              left: -120,
              top: 80,
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
              right: -150,
              top: 250,
              child: IgnorePointer(
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(45, 212, 191, 0.14),
                        Color.fromRGBO(45, 212, 191, 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          SafeArea(
            child: _selectedServiceIndex == null
                ? _buildServiceListPage(isDark, precio)
                : _buildServiceDetailPage(isDark, precio),
          ),
        ],
      ),
    );
  }
}
