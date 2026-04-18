import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../widgets/docya_snackbar.dart';
import 'terminos_screen.dart';

const kProfileGoogleApiKey = "AIzaSyDVv_barlVwHJTgLF66dP4ESUffCBuS3uA";

class CompleteProfileScreen extends StatefulWidget {
  final bool forceProfile;

  const CompleteProfileScreen({
    super.key,
    this.forceProfile = true,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroDocumentoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _auth = AuthService();

  String _tipoDocumento = 'dni';
  String _sexo = 'masculino';
  bool _aceptaTerminos = false;
  bool _guardando = false;
  DateTime? _fechaNacimiento;
  Country _country = CountryService().getAll().firstWhere(
        (country) => country.countryCode == 'AR',
      );
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _numeroDocumentoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';
    if (_userId.isEmpty) return;

    final profile = await _auth.fetchUserProfile(_userId);
    if (!mounted || profile == null) return;

    setState(() {
      _tipoDocumento = (profile['tipo_documento'] ?? 'dni').toString();
      _sexo = (profile['sexo'] ?? 'masculino').toString();
      _aceptaTerminos = profile['acepta_terminos'] == true;
      _numeroDocumentoCtrl.text =
          (profile['numero_documento'] ?? '').toString();
      _direccionCtrl.text = (profile['direccion'] ?? '').toString();

      final telefono = (profile['telefono'] ?? '').toString();
      if (telefono.startsWith('+')) {
        final match = RegExp(r'^\+(\d{1,4})(.*)$').firstMatch(telefono);
        if (match != null) {
          final code = match.group(1) ?? '';
          final nationalNumber =
              (match.group(2) ?? '').replaceAll(RegExp(r'\s+'), '');
          for (final country in CountryService().getAll()) {
            if (country.phoneCode == code) {
              _country = country;
              break;
            }
          }
          _telefonoCtrl.text = nationalNumber;
        }
      }

      final fechaRaw = profile['fecha_nacimiento']?.toString();
      if (fechaRaw != null && fechaRaw.isNotEmpty) {
        _fechaNacimiento = DateTime.tryParse(fechaRaw);
      }
    });
  }

  String get _telefonoCompleto {
    final digits = _telefonoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '+${_country.phoneCode}$digits';
  }

  bool _telefonoValido(String value) {
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaNacimiento == null) {
      DocYaSnackbar.show(
        context,
        title: "Fecha requerida",
        message: "Elegí tu fecha de nacimiento.",
        type: SnackType.error,
      );
      return;
    }

    if (!_aceptaTerminos) {
      DocYaSnackbar.show(
        context,
        title: "Términos requeridos",
        message: "Debes aceptar los términos para continuar.",
        type: SnackType.error,
      );
      return;
    }

    if (_direccionCtrl.text.trim().isEmpty) {
      DocYaSnackbar.show(
        context,
        title: "Dirección requerida",
        message: "Necesitamos tu dirección antes de continuar.",
        type: SnackType.error,
      );
      return;
    }

    final telefonoCompleto = _telefonoCompleto;
    if (!_telefonoValido(telefonoCompleto)) {
      DocYaSnackbar.show(
        context,
        title: "Teléfono inválido",
        message: "Ingresá un teléfono internacional válido.",
        type: SnackType.error,
      );
      return;
    }

    setState(() => _guardando = true);
    final result = await _auth.completeProfile(
      userId: _userId,
      telefono: telefonoCompleto,
      tipoDocumento: _tipoDocumento,
      numeroDocumento: _numeroDocumentoCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      fechaNacimientoIso: DateFormat('yyyy-MM-dd').format(_fechaNacimiento!),
      sexo: _sexo,
      aceptaTerminos: _aceptaTerminos,
    );
    setState(() => _guardando = false);

    if (!mounted) return;

    if (result['ok'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('perfilCompleto', true);

      DocYaSnackbar.show(
        context,
        title: "Perfil completo",
        message: "Ya podés continuar dentro de DocYa.",
        type: SnackType.success,
      );

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    DocYaSnackbar.show(
      context,
      title: "No se pudo guardar",
      message: result['detail'] ?? "Revisá tus datos e intentá de nuevo.",
      type: SnackType.error,
    );
  }

  InputDecoration _inputDecoration(String label,
      {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaLabel = _fechaNacimiento == null
        ? 'Seleccionar fecha'
        : DateFormat('dd/MM/yyyy').format(_fechaNacimiento!);

    return WillPopScope(
      onWillPop: () async => !widget.forceProfile,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Completar perfil'),
          automaticallyImplyLeading: !widget.forceProfile,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Necesitamos estos datos antes de solicitar un profesional.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _tipoDocumento,
                    decoration: _inputDecoration('Tipo de documento'),
                    items: const [
                      DropdownMenuItem(value: 'dni', child: Text('DNI')),
                      DropdownMenuItem(
                        value: 'pasaporte',
                        child: Text('Pasaporte'),
                      ),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (value) =>
                        setState(() => _tipoDocumento = value ?? 'dni'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _numeroDocumentoCtrl,
                    decoration: _inputDecoration('Número de documento'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresá el número de documento'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      'Teléfono internacional',
                      prefix: InkWell(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: true,
                            onSelect: (country) =>
                                setState(() => _country = country),
                          );
                        },
                        child: Container(
                          width: 92,
                          alignment: Alignment.center,
                          child: Text(
                              '${_country.flagEmoji} +${_country.phoneCode}'),
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresá tu teléfono'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  GooglePlaceAutoCompleteTextField(
                    textEditingController: _direccionCtrl,
                    googleAPIKey: kProfileGoogleApiKey,
                    debounceTime: 500,
                    isLatLngRequired: false,
                    itemClick: (prediction) {
                      _direccionCtrl.text = prediction.description ?? '';
                      _direccionCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: _direccionCtrl.text.length),
                      );
                    },
                    getPlaceDetailWithLatLng: (_) {},
                    itemBuilder: (context, index, prediction) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(prediction.description ?? ''),
                      );
                    },
                    seperatedBuilder: const Divider(height: 1),
                    boxDecoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    inputDecoration: _inputDecoration('Dirección'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickFecha,
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: _inputDecoration('Fecha de nacimiento'),
                      child: Text(fechaLabel),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _sexo,
                    decoration: _inputDecoration('Sexo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'masculino',
                        child: Text('Masculino'),
                      ),
                      DropdownMenuItem(
                        value: 'femenino',
                        child: Text('Femenino'),
                      ),
                      DropdownMenuItem(value: 'otro', child: Text('Otro')),
                    ],
                    onChanged: (value) =>
                        setState(() => _sexo = value ?? 'otro'),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _aceptaTerminos,
                    onChanged: (value) =>
                        setState(() => _aceptaTerminos = value ?? false),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        const Text('Acepto los'),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TerminosScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'términos y condiciones',
                            style: TextStyle(
                              color: Color(0xFF14B8A6),
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Text('Guardar y continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
