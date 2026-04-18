package com.docya.paciente

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ImageButton
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import com.mercadopago.sdk.android.coremethods.domain.interactor.coreMethods
import com.mercadopago.sdk.android.coremethods.domain.model.BuyerIdentification
import com.mercadopago.sdk.android.coremethods.domain.model.IdentificationType
import com.mercadopago.sdk.android.coremethods.domain.model.ResultError
import com.mercadopago.sdk.android.coremethods.domain.utils.Result
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.securitycode.SecurityCodeTextFieldEvent
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.securitycode.xml.SecurityCodeTextField
import com.mercadopago.sdk.android.domain.model.CountryCode
import com.mercadopago.sdk.android.initializer.MercadoPagoSDK
import kotlinx.coroutines.launch
import java.util.Locale

class MercadoPagoSavedCardActivity : AppCompatActivity() {
    companion object {
        const val REQUEST_CODE = 4108

        const val EXTRA_PUBLIC_KEY = "public_key"
        const val EXTRA_COUNTRY_CODE = "country_code"
        const val EXTRA_TITLE = "title"
        const val EXTRA_DESCRIPTION = "description"
        const val EXTRA_PAYER_EMAIL = "payer_email"
        const val EXTRA_CARDHOLDER_NAME = "cardholder_name"
        const val EXTRA_IDENTIFICATION_TYPE = "identification_type"
        const val EXTRA_IDENTIFICATION_NUMBER = "identification_number"
        const val EXTRA_SAVED_CARD_ID = "saved_card_id"
        const val EXTRA_SAVED_CARD_BRAND = "saved_card_brand"
        const val EXTRA_SAVED_CARD_LAST_FOUR = "saved_card_last_four"
        const val EXTRA_SAVED_CARD_EXPIRATION = "saved_card_expiration"
        const val EXTRA_PAYMENT_METHOD_ID = "payment_method_id"
        const val EXTRA_ISSUER_ID = "issuer_id"

        const val RESULT_STATUS = "status"
        const val RESULT_TOKEN = "token"
        const val RESULT_ERROR = "error"
        const val RESULT_PAYMENT_METHOD_ID = "payment_method_id"
        const val RESULT_ISSUER_ID = "issuer_id"
        const val RESULT_IDENTIFICATION_TYPE = "identification_type"
        const val RESULT_IDENTIFICATION_NUMBER = "identification_number"
        const val RESULT_PAYER_EMAIL = "payer_email"
        const val RESULT_CARDHOLDER_NAME = "cardholder_name"
    }

    private lateinit var textTitle: TextView
    private lateinit var textDescription: TextView
    private lateinit var textSavedCardInfo: TextView
    private lateinit var textError: TextView
    private lateinit var layoutCardholderName: TextInputLayout
    private lateinit var layoutEmail: TextInputLayout
    private lateinit var textIdentificationLabel: TextView
    private lateinit var layoutIdentificationNumber: TextInputLayout
    private lateinit var inputCardholderName: TextInputEditText
    private lateinit var inputEmail: TextInputEditText
    private lateinit var inputIdentificationNumber: TextInputEditText
    private lateinit var spinnerIdentificationType: Spinner
    private lateinit var inputSecurityCode: SecurityCodeTextField
    private lateinit var buttonAuthorize: Button

    private var identificationTypes: List<IdentificationType> = emptyList()
    private var securityCodeFilled = false
    private var isSubmitting = false
    private var savedCardId: String? = null
    private var paymentMethodId: String? = null
    private var issuerId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            setContentView(R.layout.activity_mercado_pago_saved_card)
            bindViews()
            bindStaticContent()
            setupMercadoPagoSdk()
            setupFields()
            loadIdentificationTypes()
        } catch (exception: Throwable) {
            failFlow(exception.message ?: "No se pudo iniciar la tarjeta guardada.")
        }
    }

    private fun bindViews() {
        findViewById<ImageButton>(R.id.buttonClose).setOnClickListener { cancelFlow() }
        textTitle = findViewById(R.id.textTitle)
        textDescription = findViewById(R.id.textDescription)
        textSavedCardInfo = findViewById(R.id.textSavedCardInfo)
        textError = findViewById(R.id.textError)
        layoutCardholderName = findViewById(R.id.layoutCardholderName)
        layoutEmail = findViewById(R.id.layoutEmail)
        textIdentificationLabel = findViewById(R.id.textIdentificationLabel)
        layoutIdentificationNumber = findViewById(R.id.layoutIdentificationNumber)
        inputCardholderName = findViewById(R.id.inputCardholderName)
        inputEmail = findViewById(R.id.inputEmail)
        inputIdentificationNumber = findViewById(R.id.inputIdentificationNumber)
        spinnerIdentificationType = findViewById(R.id.spinnerIdentificationType)
        inputSecurityCode = findViewById(R.id.inputSecurityCode)
        buttonAuthorize = findViewById(R.id.buttonAuthorize)
        buttonAuthorize.setOnClickListener { submit() }
    }

    private fun bindStaticContent() {
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val description = intent.getStringExtra(EXTRA_DESCRIPTION).orEmpty()
        val email = intent.getStringExtra(EXTRA_PAYER_EMAIL).orEmpty()
        val cardholderName = intent.getStringExtra(EXTRA_CARDHOLDER_NAME).orEmpty()
        val identificationNumber = intent.getStringExtra(EXTRA_IDENTIFICATION_NUMBER).orEmpty()
        val savedCardBrand = intent.getStringExtra(EXTRA_SAVED_CARD_BRAND).orEmpty()
        val savedCardLastFour = intent.getStringExtra(EXTRA_SAVED_CARD_LAST_FOUR).orEmpty()
        val savedCardExpiration = intent.getStringExtra(EXTRA_SAVED_CARD_EXPIRATION).orEmpty()

        savedCardId = intent.getStringExtra(EXTRA_SAVED_CARD_ID)
        paymentMethodId = intent.getStringExtra(EXTRA_PAYMENT_METHOD_ID)
        issuerId = intent.getStringExtra(EXTRA_ISSUER_ID)
        textTitle.text = if (title.isBlank()) "Autoriza tu tarjeta guardada" else title
        textDescription.text = if (description.isBlank()) {
            "Solo vas a confirmar el codigo de seguridad. DocYa reutiliza esta tarjeta de forma segura."
        } else {
            description
        }
        inputEmail.setText(email)
        inputCardholderName.setText(cardholderName)
        inputIdentificationNumber.setText(identificationNumber)

        layoutCardholderName.visibility = View.GONE
        layoutEmail.visibility = View.GONE
        textIdentificationLabel.visibility = View.GONE
        spinnerIdentificationType.visibility = View.GONE
        layoutIdentificationNumber.visibility = View.GONE

        textSavedCardInfo.text = buildString {
            append(if (savedCardBrand.isBlank()) "Tarjeta guardada" else savedCardBrand)
            if (savedCardLastFour.isNotBlank()) append(" **** $savedCardLastFour")
            if (savedCardExpiration.isNotBlank()) append(" · vence $savedCardExpiration")
        }
    }

    private fun setupMercadoPagoSdk() {
        val publicKey = intent.getStringExtra(EXTRA_PUBLIC_KEY).orEmpty()
        val countryCode = intent.getStringExtra(EXTRA_COUNTRY_CODE).orEmpty()
        if (publicKey.isBlank()) {
            showError("No se encontro la clave publica de Mercado Pago.")
            buttonAuthorize.isEnabled = false
            return
        }

        if (!MercadoPagoSDK.isInitialized) {
            MercadoPagoSDK.initialize(
                context = applicationContext,
                publicKey = publicKey,
                countryCode = countryCode.toCountryCode(),
            )
        }
    }

    private fun setupFields() {
        inputSecurityCode.securityCodeSize = 3
        inputSecurityCode.onEvent = { event ->
            when (event) {
                is SecurityCodeTextFieldEvent.OnInputFilled -> securityCodeFilled = event.isFilled
                is SecurityCodeTextFieldEvent.IsValid -> securityCodeFilled = event.isValid
                else -> Unit
            }
        }
    }

    private fun loadIdentificationTypes() {
        lifecycleScope.launch {
            when (val result = MercadoPagoSDK.getInstance().coreMethods.getIdentificationTypes()) {
                is Result.Success<*> -> {
                    val types = result.data as List<IdentificationType>
                    identificationTypes = types
                    val labels = identificationTypes.map { it.name ?: it.id ?: "Documento" }
                    spinnerIdentificationType.adapter = ArrayAdapter(
                        this@MercadoPagoSavedCardActivity,
                        android.R.layout.simple_spinner_dropdown_item,
                        labels,
                    )

                    val preferred = intent.getStringExtra(EXTRA_IDENTIFICATION_TYPE)
                        .orEmpty()
                        .uppercase(Locale.ROOT)
                    val initialIndex = identificationTypes.indexOfFirst {
                        (it.name ?: it.id ?: "").uppercase(Locale.ROOT) == preferred
                    }.takeIf { it >= 0 } ?: 0
                    spinnerIdentificationType.setSelection(initialIndex)
                }

                is Result.Error<*> -> showError(
                    readableError(
                        result.error as ResultError,
                        "No se pudieron cargar los tipos de documento.",
                    ),
                )
            }
        }
    }

    private fun submit() {
        if (isSubmitting) return
        clearError()

        val cardholderName = inputCardholderName.text?.toString()?.trim().orEmpty()
        val payerEmail = inputEmail.text?.toString()?.trim().orEmpty()
        val identificationNumber = inputIdentificationNumber.text?.toString()?.trim().orEmpty()
        val identificationType = identificationTypes.getOrNull(spinnerIdentificationType.selectedItemPosition)
        val securityCodeState = runCatching { inputSecurityCode.state }.getOrNull()

        if (savedCardId.isNullOrBlank()) {
            showError("No encontramos la tarjeta guardada.")
            return
        }
        if (cardholderName.isBlank() || payerEmail.isBlank() || identificationNumber.isBlank() || identificationType == null) {
            showError("No pudimos recuperar los datos necesarios de esta tarjeta. Volve a cargarla como nueva.")
            return
        }
        if (!securityCodeFilled || securityCodeState == null) {
            showError("Ingresa el codigo de seguridad.")
            return
        }

        isSubmitting = true
        buttonAuthorize.isEnabled = false
        buttonAuthorize.text = "Autorizando..."

        lifecycleScope.launch {
            val result = MercadoPagoSDK.getInstance().coreMethods.generateCardToken(
                cardId = savedCardId.orEmpty(),
                securityCodeState = securityCodeState,
                buyerIdentification = BuyerIdentification(
                    name = cardholderName,
                    number = identificationNumber,
                    type = identificationType.name ?: identificationType.id,
                ),
            )

            when (result) {
                is Result.Success<*> -> {
                    val tokenResult = result.data as com.mercadopago.sdk.android.coremethods.domain.model.CardToken
                    setResult(
                        Activity.RESULT_OK,
                        Intent().apply {
                            putExtra(RESULT_STATUS, "success")
                            putExtra(RESULT_TOKEN, tokenResult.token)
                            putExtra(RESULT_PAYMENT_METHOD_ID, paymentMethodId)
                            putExtra(RESULT_ISSUER_ID, issuerId)
                            putExtra(RESULT_IDENTIFICATION_TYPE, identificationType.name ?: identificationType.id)
                            putExtra(RESULT_IDENTIFICATION_NUMBER, identificationNumber)
                            putExtra(RESULT_PAYER_EMAIL, payerEmail)
                            putExtra(RESULT_CARDHOLDER_NAME, cardholderName)
                        },
                    )
                    finish()
                }

                is Result.Error<*> -> {
                    isSubmitting = false
                    buttonAuthorize.isEnabled = true
                    buttonAuthorize.text = "Autorizar tarjeta guardada"
                    showError(
                        readableError(
                            result.error as ResultError,
                            "No se pudo validar la tarjeta guardada.",
                        ),
                    )
                }
            }
        }
    }

    private fun cancelFlow() {
        setResult(
            Activity.RESULT_CANCELED,
            Intent().apply { putExtra(RESULT_STATUS, "cancelled") },
        )
        finish()
    }

    private fun failFlow(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        setResult(
            Activity.RESULT_CANCELED,
            Intent().apply {
                putExtra(RESULT_STATUS, "failed")
                putExtra(RESULT_ERROR, message)
            },
        )
        finish()
    }

    private fun readableError(error: ResultError, fallback: String): String {
        return when (error) {
            is ResultError.Request -> error.message.ifBlank { fallback }
            is ResultError.Validation -> error.message.ifBlank { fallback }
        }
    }

    private fun showError(message: String) {
        textError.visibility = View.VISIBLE
        textError.text = message
    }

    private fun clearError() {
        textError.visibility = View.GONE
        textError.text = ""
    }

    private fun String.toCountryCode(): CountryCode {
        return runCatching { CountryCode.valueOf(this.uppercase(Locale.ROOT)) }
            .getOrDefault(CountryCode.ARG)
    }
}
