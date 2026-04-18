import 'dart:convert';

import 'package:http/http.dart' as http;

import '../globals.dart';

class PaymentMethodsService {
  Future<Map<String, dynamic>> fetchPublicConfig() async {
    final res = await http.get(Uri.parse('$API_URL/pagos/public-config'));
    if (res.statusCode != 200) {
      throw Exception('No se pudo cargar la configuración de pago');
    }

    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<List<Map<String, dynamic>>> fetchMethods(String pacienteUuid) async {
    final res =
        await http.get(Uri.parse('$API_URL/pagos/metodos/$pacienteUuid'));
    if (res.statusCode != 200) {
      throw Exception('No se pudieron cargar los métodos');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List? ?? <dynamic>[]);
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deleteMethod(int id) async {
    final res = await http.delete(Uri.parse('$API_URL/pagos/metodos/$id'));
    if (res.statusCode != 200) {
      throw Exception('No se pudo eliminar la tarjeta');
    }
  }

  Uri buildEmbeddedPaymentUrl({
    required String pacienteUuid,
    required int consultaId,
    required double monto,
    required String tipo,
    required String motivo,
  }) {
    return Uri.parse('$API_URL/pagos/embebido/formulario').replace(
      queryParameters: {
        'paciente_uuid': pacienteUuid,
        'consulta_id': consultaId.toString(),
        'monto': monto.toStringAsFixed(0),
        'tipo': tipo,
        'motivo': motivo,
      },
    );
  }

  Future<Map<String, dynamic>> authorizeNativePayment({
    required int consultaId,
    required String pacienteUuid,
    required double monto,
    required String motivo,
    required String tipo,
    required String token,
    required String paymentMethodId,
    String? issuerId,
    String? payerEmail,
    String? identificationType,
    String? identificationNumber,
    bool saveCard = false,
    int installments = 1,
  }) async {
    final res = await http.post(
      Uri.parse('$API_URL/pagos/embebido/autorizar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'consulta_id': consultaId,
        'paciente_uuid': pacienteUuid,
        'monto': monto,
        'motivo': motivo,
        'tipo': tipo,
        'token': token,
        'payment_method_id': paymentMethodId,
        'issuer_id': issuerId,
        'payer_email': payerEmail,
        'identification_type': identificationType,
        'identification_number': identificationNumber,
        'save_card': saveCard,
        'installments': installments,
      }),
    );

    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    if (res.statusCode != 200) {
      final detail = body['detail'];
      String? message;
      if (detail is Map) {
        message = detail['message']?.toString() ??
            detail['status_detail']?.toString() ??
            (() {
              final causes = detail['cause'];
              if (causes is List && causes.isNotEmpty && causes.first is Map) {
                return (causes.first as Map)['description']?.toString();
              }
              return null;
            })();
      }
      throw Exception(
        message ??
            body['detail']?.toString() ??
            body['message']?.toString() ??
            'No se pudo autorizar el pago',
      );
    }

    return body;
  }
}
