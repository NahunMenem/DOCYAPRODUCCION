package com.docya.paciente

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "docya/mercado_pago_native"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "collectCardToken" -> {
                        if (pendingResult != null) {
                            result.error("in_progress", "Ya hay una autorización en curso.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            pendingResult = result
                            val intent = Intent(this, MercadoPagoNativeCardActivity::class.java).apply {
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_PUBLIC_KEY, call.argument<String>("publicKey"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_COUNTRY_CODE, call.argument<String>("countryCode"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_AMOUNT, call.argument<Double>("amount") ?: 0.0)
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_TITLE, call.argument<String>("title"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_DESCRIPTION, call.argument<String>("description"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_PAYER_EMAIL, call.argument<String>("payerEmail"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_CARDHOLDER_NAME, call.argument<String>("cardholderName"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_IDENTIFICATION_TYPE, call.argument<String>("identificationType"))
                                putExtra(MercadoPagoNativeCardActivity.EXTRA_IDENTIFICATION_NUMBER, call.argument<String>("identificationNumber"))
                            }
                            startActivityForResult(intent, MercadoPagoNativeCardActivity.REQUEST_CODE)
                        } catch (exception: Throwable) {
                            pendingResult = null
                            result.error(
                                "launch_failed",
                                exception.message ?: "No se pudo abrir la pantalla nativa de tarjeta.",
                                null,
                            )
                        }
                    }

                    "collectSavedCardToken" -> {
                        if (pendingResult != null) {
                            result.error("in_progress", "Ya hay una autorizacion en curso.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            pendingResult = result
                            val intent = Intent(this, MercadoPagoSavedCardActivity::class.java).apply {
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_PUBLIC_KEY, call.argument<String>("publicKey"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_COUNTRY_CODE, call.argument<String>("countryCode"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_TITLE, call.argument<String>("title"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_DESCRIPTION, call.argument<String>("description"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_PAYER_EMAIL, call.argument<String>("payerEmail"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_CARDHOLDER_NAME, call.argument<String>("cardholderName"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_IDENTIFICATION_TYPE, call.argument<String>("identificationType"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_IDENTIFICATION_NUMBER, call.argument<String>("identificationNumber"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_SAVED_CARD_ID, call.argument<String>("savedCardId"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_SAVED_CARD_BRAND, call.argument<String>("savedCardBrand"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_SAVED_CARD_LAST_FOUR, call.argument<String>("savedCardLastFour"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_SAVED_CARD_EXPIRATION, call.argument<String>("savedCardExpiration"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_PAYMENT_METHOD_ID, call.argument<String>("paymentMethodId"))
                                putExtra(MercadoPagoSavedCardActivity.EXTRA_ISSUER_ID, call.argument<String>("issuerId"))
                            }
                            startActivityForResult(intent, MercadoPagoSavedCardActivity.REQUEST_CODE)
                        } catch (exception: Throwable) {
                            pendingResult = null
                            result.error(
                                "launch_failed",
                                exception.message ?: "No se pudo abrir la pantalla de tarjeta guardada.",
                                null,
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != MercadoPagoNativeCardActivity.REQUEST_CODE &&
            requestCode != MercadoPagoSavedCardActivity.REQUEST_CODE) return

        val callback = pendingResult ?: return
        pendingResult = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            callback.success(
                mapOf(
                    "status" to (data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_STATUS) ?: "success"),
                    "token" to data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_TOKEN),
                    "payment_method_id" to (
                        data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_PAYMENT_METHOD_ID)
                            ?: data.getStringExtra(MercadoPagoSavedCardActivity.RESULT_PAYMENT_METHOD_ID)
                        ),
                    "issuer_id" to (
                        data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_ISSUER_ID)
                            ?: data.getStringExtra(MercadoPagoSavedCardActivity.RESULT_ISSUER_ID)
                        ),
                    "error" to data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_ERROR),
                    "identification_type" to data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_IDENTIFICATION_TYPE),
                    "identification_number" to data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_IDENTIFICATION_NUMBER),
                    "payer_email" to data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_PAYER_EMAIL),
                    "cardholder_name" to data.getStringExtra(MercadoPagoNativeCardActivity.RESULT_CARDHOLDER_NAME),
                    "save_card" to data.getBooleanExtra(MercadoPagoNativeCardActivity.RESULT_SAVE_CARD, true),
                ),
            )
            return
        }

        callback.success(
            mapOf(
                "status" to (data?.getStringExtra(MercadoPagoNativeCardActivity.RESULT_STATUS) ?: "cancelled"),
                "error" to data?.getStringExtra(MercadoPagoNativeCardActivity.RESULT_ERROR),
            ),
        )
    }
}
