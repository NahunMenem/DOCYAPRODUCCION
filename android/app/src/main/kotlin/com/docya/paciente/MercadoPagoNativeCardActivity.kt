package com.docya.paciente

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.ImageButton
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.google.android.material.textfield.TextInputEditText
import com.mercadopago.sdk.android.coremethods.domain.interactor.coreMethods
import com.mercadopago.sdk.android.coremethods.domain.model.BuyerIdentification
import com.mercadopago.sdk.android.coremethods.domain.model.IdentificationType
import com.mercadopago.sdk.android.coremethods.domain.model.PaymentMethod
import com.mercadopago.sdk.android.coremethods.domain.model.ResultError
import com.mercadopago.sdk.android.coremethods.domain.utils.Result
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.cardnumber.CardNumberTextFieldEvent
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.expirationdate.ExpirationDateTextFieldEvent
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.expirationdate.xml.ExpirationDateTextField
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.identificationtextfield.IdentificationTextFieldEvent
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.securitycode.SecurityCodeTextFieldEvent
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.securitycode.xml.SecurityCodeTextField
import com.mercadopago.sdk.android.coremethods.ui.components.textfield.cardnumber.xml.CardNumberTextField
import com.mercadopago.sdk.android.domain.model.CountryCode
import com.mercadopago.sdk.android.initializer.MercadoPagoSDK
import kotlinx.coroutines.launch
import java.util.Locale

class MercadoPagoNativeCardActivity : AppCompatActivity() {
    companion object {
        const val REQUEST_CODE = 4107

        const val EXTRA_PUBLIC_KEY = "public_key"
        const val EXTRA_COUNTRY_CODE = "country_code"
        const val EXTRA_AMOUNT = "amount"
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

        const val RESULT_STATUS = "status"
        const val RESULT_TOKEN = "token"
        const val RESULT_PAYMENT_METHOD_ID = "payment_method_id"
        const val RESULT_ISSUER_ID = "issuer_id"
        const val RESULT_ERROR = "error"
        const val RESULT_IDENTIFICATION_TYPE = "identification_type"
        const val RESULT_IDENTIFICATION_NUMBER = "identification_number"
        const val RESULT_PAYER_EMAIL = "payer_email"
        const val RESULT_CARDHOLDER_NAME = "cardholder_name"
        const val RESULT_SAVE_CARD = "save_card"
    }

    private lateinit var textTitle: TextView
    private lateinit var textAmount: TextView
    private lateinit var textDescription: TextView
    private lateinit var textSavedCardInfo: TextView
    private lateinit var textError: TextView
    private lateinit var textCardNumberLabel: TextView
    private lateinit var inputCardholderName: TextInputEditText
    private lateinit var inputEmail: TextInputEditText
    private lateinit var inputIdentificationNumber: TextInputEditText
    private lateinit var spinnerIdentificationType: Spinner
    private lateinit var inputCardNumber: CardNumberTextField
    private lateinit var inputExpirationDate: ExpirationDateTextField
    private lateinit var inputSecurityCode: SecurityCodeTextField
    private lateinit var switchSaveCard: CheckBox
    private lateinit var buttonAuthorize: Button
    private lateinit var layoutExpirationRow: View

    private var identificationTypes: List<IdentificationType> = emptyList()
    private var selectedIdentificationIndex = 0
    private var selectedPaymentMethod: PaymentMethod? = null
    private var selectedIssuerId: String? = null
    private var cardNumberValid = false
    private var expirationValid = false
    private var securityCodeFilled = false
    private var isSubmitting = false
    private var savedCardId: String? = null
    private var isSavedCardMode = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            setContentView(R.layout.activity_mercado_pago_native_card)

            bindViews()
            bindStaticContent()
            setupMercadoPagoSdk()
            setupFields()
            loadIdentificationTypes()
        } catch (exception: Throwable) {
            failFlow(exception.message ?: "No se pudo iniciar la pantalla de tarjeta.")
        }
    }

    private fun bindViews() {
        findViewById<ImageButton>(R.id.buttonClose).setOnClickListener { cancelFlow() }
        textTitle = findViewById(R.id.textTitle)
        textAmount = findViewById(R.id.textAmount)
        textDescription = findViewById(R.id.textDescription)
        textSavedCardInfo = findViewById(R.id.textSavedCardInfo)
        textError = findViewById(R.id.textError)
        textCardNumberLabel = findViewById(R.id.textCardNumberLabel)
        inputCardholderName = findViewById(R.id.inputCardholderName)
        inputEmail = findViewById(R.id.inputEmail)
        inputIdentificationNumber = findViewById(R.id.inputIdentificationNumber)
        spinnerIdentificationType = findViewById(R.id.spinnerIdentificationType)
        inputCardNumber = findViewById(R.id.inputCardNumber)
        inputExpirationDate = findViewById(R.id.inputExpirationDate)
        inputSecurityCode = findViewById(R.id.inputSecurityCode)
        switchSaveCard = findViewById(R.id.switchSaveCard)
        buttonAuthorize = findViewById(R.id.buttonAuthorize)
        layoutExpirationRow = findViewById(R.id.layoutExpirationRow)
        buttonAuthorize.setOnClickListener { submit() }
    }

    private fun bindStaticContent() {
        val amount = intent.getDoubleExtra(EXTRA_AMOUNT, 0.0)
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val description = intent.getStringExtra(EXTRA_DESCRIPTION).orEmpty()
        val email = intent.getStringExtra(EXTRA_PAYER_EMAIL).orEmpty()
        val cardholderName = intent.getStringExtra(EXTRA_CARDHOLDER_NAME).orEmpty()
        val identificationNumber = intent.getStringExtra(EXTRA_IDENTIFICATION_NUMBER).orEmpty()
        savedCardId = intent.getStringExtra(EXTRA_SAVED_CARD_ID)
        isSavedCardMode = !savedCardId.isNullOrBlank()
        val savedCardBrand = intent.getStringExtra(EXTRA_SAVED_CARD_BRAND).orEmpty()
        val savedCardLastFour = intent.getStringExtra(EXTRA_SAVED_CARD_LAST_FOUR).orEmpty()
        val savedCardExpiration = intent.getStringExtra(EXTRA_SAVED_CARD_EXPIRATION).orEmpty()

        textTitle.text = if (title.isBlank()) "Autorizá tu consulta" else title
        textAmount.text = formatAmount(amount)
        textDescription.text = description
        inputEmail.setText(email)
        inputCardholderName.setText(cardholderName)
        inputIdentificationNumber.setText(identificationNumber)

        if (isSavedCardMode) {
            textSavedCardInfo.visibility = View.VISIBLE
            textSavedCardInfo.text = buildString {
                append("Usando ")
                append(if (savedCardBrand.isBlank()) "tu tarjeta guardada" else savedCardBrand)
                if (savedCardLastFour.isNotBlank()) {
                    append(" •••• ")
                    append(savedCardLastFour)
                }
                if (savedCardExpiration.isNotBlank()) {
                    append(" · vence ")
                    append(savedCardExpiration)
                }
            }
            textCardNumberLabel.visibility = View.GONE
            inputCardNumber.visibility = View.GONE
            layoutExpirationRow.visibility = View.GONE
            switchSaveCard.visibility = View.GONE
            buttonAuthorize.text = "Autorizar tarjeta guardada"
            cardNumberValid = true
            expirationValid = true
        }

    }

    private fun setupMercadoPagoSdk() {
        val publicKey = intent.getStringExtra(EXTRA_PUBLIC_KEY).orEmpty()
        val countryCode = intent.getStringExtra(EXTRA_COUNTRY_CODE).orEmpty()
        if (publicKey.isBlank()) {
            showError("No se encontró la clave pública de Mercado Pago.")
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
        if (isSavedCardMode) {
            inputSecurityCode.securityCodeSize = 3
            inputSecurityCode.onEvent = { event ->
                when (event) {
                    is SecurityCodeTextFieldEvent.OnInputFilled -> securityCodeFilled = event.isFilled
                    is SecurityCodeTextFieldEvent.IsValid -> securityCodeFilled = event.isValid
                    else -> Unit
                }
            }
            return
        }

        inputCardNumber.onEvent = { event ->
            when (event) {
                is CardNumberTextFieldEvent.IsValid -> {
                    cardNumberValid = event.isValid
                    if (!event.isValid) {
                        selectedPaymentMethod = null
                    }
                }

                is CardNumberTextFieldEvent.OnBinChanged -> {
                    selectedIssuerId = null
                    val bin = event.cardBin.orEmpty()
                    if (bin.length >= 8) {
                        resolvePaymentMethod(bin)
                    } else {
                        selectedPaymentMethod = null
                        inputSecurityCode.securityCodeSize = 3
                    }
                }

                else -> Unit
            }
        }

        inputExpirationDate.onEvent = { event ->
            when (event) {
                is ExpirationDateTextFieldEvent.IsValid -> expirationValid = event.isValid
                else -> Unit
            }
        }

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
                        this@MercadoPagoNativeCardActivity,
                        android.R.layout.simple_spinner_dropdown_item,
                        labels,
                    )

                    val preferred = intent.getStringExtra(EXTRA_IDENTIFICATION_TYPE)
                        .orEmpty()
                        .uppercase(Locale.ROOT)
                    val initialIndex = identificationTypes.indexOfFirst {
                        (it.name ?: it.id ?: "").uppercase(Locale.ROOT) == preferred
                    }.takeIf { it >= 0 } ?: 0
                    selectedIdentificationIndex = initialIndex
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

    private fun resolvePaymentMethod(bin: String) {
        lifecycleScope.launch {
            when (val paymentMethodsResult = MercadoPagoSDK.getInstance().coreMethods.getPaymentMethods(bin = bin)) {
                is Result.Success<*> -> {
                    val paymentMethods = paymentMethodsResult.data as List<PaymentMethod>
                    selectedPaymentMethod = paymentMethods.firstOrNull()
                    val securityLength = selectedPaymentMethod?.card?.securityCode?.length ?: 3
                    inputSecurityCode.securityCodeSize = securityLength
                    selectedPaymentMethod?.id?.let { paymentMethodId ->
                        when (val issuerResult = MercadoPagoSDK.getInstance().coreMethods.getCardIssuers(bin, paymentMethodId)) {
                            is Result.Success<*> -> {
                                val issuers = issuerResult.data as List<com.mercadopago.sdk.android.coremethods.domain.model.CardIssuer>
                                selectedIssuerId = issuers.firstOrNull()?.id
                            }

                            is Result.Error<*> -> {
                                selectedIssuerId = null
                            }
                        }
                    }
                }

                is Result.Error<*> -> {
                    selectedPaymentMethod = null
                    selectedIssuerId = null
                }
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

        if (cardholderName.isBlank()) {
            showError("Ingresá el nombre del titular.")
            return
        }
        if (payerEmail.isBlank()) {
            showError("Ingresá el email del titular.")
            return
        }
        if (identificationType == null) {
            showError("Seleccioná un tipo de documento.")
            return
        }
        if (identificationNumber.isBlank()) {
            showError("Ingresá el número de documento.")
            return
        }
        if (!cardNumberValid || !expirationValid || !securityCodeFilled) {
            showError("Revisá los datos de la tarjeta antes de continuar.")
            return
        }

        val cardNumberState = runCatching { inputCardNumber.state }.getOrNull()
        val expirationState = runCatching { inputExpirationDate.state }.getOrNull()
        val securityCodeState = runCatching { inputSecurityCode.state }.getOrNull()
        if (cardNumberState == null || expirationState == null || securityCodeState == null) {
            showError("El formulario todavía se está preparando. Intentá nuevamente.")
            return
        }

        isSubmitting = true
        buttonAuthorize.isEnabled = false
        buttonAuthorize.text = "Autorizando..."

        lifecycleScope.launch {
            val paymentMethodId = resolvePaymentMethodId(cardNumberState)
            if (paymentMethodId.isNullOrBlank()) {
                isSubmitting = false
                buttonAuthorize.isEnabled = true
                buttonAuthorize.text = "Autorizar tarjeta"
                showError("Todavía no pudimos identificar la tarjeta. Esperá un segundo e intentá otra vez.")
                return@launch
            }

            val result = MercadoPagoSDK.getInstance().coreMethods.generateCardToken(
                cardNumberState = cardNumberState,
                expirationDateState = expirationState,
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
                            putExtra(RESULT_ISSUER_ID, selectedIssuerId)
                            putExtra(RESULT_IDENTIFICATION_TYPE, identificationType.name ?: identificationType.id)
                            putExtra(RESULT_IDENTIFICATION_NUMBER, identificationNumber)
                            putExtra(RESULT_PAYER_EMAIL, payerEmail)
                            putExtra(RESULT_CARDHOLDER_NAME, cardholderName)
                            putExtra(RESULT_SAVE_CARD, switchSaveCard.isChecked)
                        },
                    )
                    finish()
                }

                is Result.Error<*> -> {
                    isSubmitting = false
                    buttonAuthorize.isEnabled = true
                    buttonAuthorize.text = "Autorizar tarjeta"
                    showError(readableError(result.error as ResultError, "No se pudo tokenizar la tarjeta."))
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

    private suspend fun resolvePaymentMethodId(
        cardNumberState: com.mercadopago.sdk.android.coremethods.ui.components.textfield.pcitextfield.PCIFieldState,
    ): String? {
        selectedPaymentMethod?.id?.takeIf { it.isNotBlank() }?.let { return it }

        val rawDigits = readCardDigits(cardNumberState)
        if (rawDigits.length < 8) {
            return null
        }

        val bin = rawDigits.take(8)
        return when (val paymentMethodsResult = MercadoPagoSDK.getInstance().coreMethods.getPaymentMethods(bin = bin)) {
            is Result.Success<*> -> {
                val paymentMethods = paymentMethodsResult.data as List<PaymentMethod>
                selectedPaymentMethod = paymentMethods.firstOrNull()
                val resolvedPaymentMethodId = selectedPaymentMethod?.id
                val securityLength = selectedPaymentMethod?.card?.securityCode?.length ?: 3
                inputSecurityCode.securityCodeSize = securityLength
                if (!resolvedPaymentMethodId.isNullOrBlank()) {
                    resolveIssuer(bin, resolvedPaymentMethodId)
                }
                resolvedPaymentMethodId
            }

            is Result.Error<*> -> null
        }
    }

    private suspend fun resolveIssuer(bin: String, paymentMethodId: String) {
        when (val issuerResult = MercadoPagoSDK.getInstance().coreMethods.getCardIssuers(bin, paymentMethodId)) {
            is Result.Success<*> -> {
                val issuers = issuerResult.data as List<com.mercadopago.sdk.android.coremethods.domain.model.CardIssuer>
                selectedIssuerId = issuers.firstOrNull()?.id
            }

            is Result.Error<*> -> {
                selectedIssuerId = null
            }
        }
    }

    private fun readCardDigits(
        cardNumberState: com.mercadopago.sdk.android.coremethods.ui.components.textfield.pcitextfield.PCIFieldState,
    ): String {
        val rawInput = runCatching {
            val getter = cardNumberState.javaClass.getMethod("getInput\$core_methods_release")
            getter.invoke(cardNumberState) as? String
        }.getOrNull().orEmpty()

        return rawInput.filter { digit -> digit.isDigit() }
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

    override fun onBackPressed() {
        cancelFlow()
    }

    private fun showError(message: String) {
        textError.visibility = View.VISIBLE
        textError.text = message
    }

    private fun clearError() {
        textError.visibility = View.GONE
        textError.text = ""
    }

    private fun readableError(error: ResultError, fallback: String): String {
        return when (error) {
            is ResultError.Request -> error.message
            is ResultError.Validation -> error.message
            else -> fallback
        }
    }

    private fun formatAmount(amount: Double): String {
        return "$" + "%,.0f".format(Locale("es", "AR"), amount)
    }

    private fun String.toCountryCode(): CountryCode {
        return try {
            CountryCode.valueOf(ifBlank { "ARG" }.uppercase(Locale.ROOT))
        } catch (_: IllegalArgumentException) {
            CountryCode.ARG
        }
    }
}
