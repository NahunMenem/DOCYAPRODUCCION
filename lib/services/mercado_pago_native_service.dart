import 'dart:io';

import 'package:flutter/services.dart';

class MercadoPagoNativeService {
  static const MethodChannel _channel =
      MethodChannel('docya/mercado_pago_native');

  Future<Map<String, dynamic>> collectCardToken({
    required String publicKey,
    required String countryCode,
    required double amount,
    required String title,
    required String description,
    required String payerEmail,
    required String cardholderName,
    required String identificationType,
    required String identificationNumber,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'La captura nativa de tarjeta hoy está disponible en Android.',
      );
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'collectCardToken',
      {
        'publicKey': publicKey,
        'countryCode': countryCode,
        'amount': amount,
        'title': title,
        'description': description,
        'payerEmail': payerEmail,
        'cardholderName': cardholderName,
        'identificationType': identificationType,
        'identificationNumber': identificationNumber,
      },
    );

    return Map<String, dynamic>.from(result ?? const {});
  }

  Future<Map<String, dynamic>> collectSavedCardToken({
    required String publicKey,
    required String countryCode,
    required String title,
    required String description,
    required String payerEmail,
    required String cardholderName,
    required String identificationType,
    required String identificationNumber,
    required String savedCardId,
    required String savedCardBrand,
    required String savedCardLastFour,
    required String savedCardExpiration,
    String? paymentMethodId,
    String? issuerId,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'La reutilizacion nativa de tarjeta hoy esta disponible en Android.',
      );
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'collectSavedCardToken',
      {
        'publicKey': publicKey,
        'countryCode': countryCode,
        'title': title,
        'description': description,
        'payerEmail': payerEmail,
        'cardholderName': cardholderName,
        'identificationType': identificationType,
        'identificationNumber': identificationNumber,
        'savedCardId': savedCardId,
        'savedCardBrand': savedCardBrand,
        'savedCardLastFour': savedCardLastFour,
        'savedCardExpiration': savedCardExpiration,
        'paymentMethodId': paymentMethodId,
        'issuerId': issuerId,
      },
    );

    return Map<String, dynamic>.from(result ?? const {});
  }
}
