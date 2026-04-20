import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // URL del backend en Railway
  static const String BASE_URL =
      'https://docya-railway-production.up.railway.app';
  static const Duration _requestTimeout = Duration(seconds: 20);

  // 🔑 Client ID de Google (Android)
  static const String GOOGLE_SERVER_CLIENT_ID =
      "117956759164-9q555tbkl8ulrmcapgj4emoqn827ltti.apps.googleusercontent.com";
  static const String GOOGLE_IOS_CLIENT_ID =
      "117956759164-mqep8e78d7fraoki2uqvcf4ja8m7ct5t.apps.googleusercontent.com";

  // ---------------------------------------------------------------
  // LOGIN EMAIL + PASSWORD
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$BASE_URL/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);

      print("📥 LOGIN STATUS: ${res.statusCode}");
      print("📥 LOGIN BODY: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        return {
          "ok": true,
          "access_token": data['access_token'],
          "user_id": data['user_id']?.toString() ??
              data['user']?['id']?.toString() ??
              "",
          "full_name":
              data['full_name'] ?? data['user']?['full_name'] ?? "Usuario",
          "email": data['user']?['email'] ?? email,
          "perfil_completo": data['perfil_completo'] == true ||
              data['user']?['perfil_completo'] == true,
        };
      }

      final err = jsonDecode(res.body);
      return {"ok": false, "detail": err["detail"] ?? "Credenciales inválidas"};
    } catch (e) {
      print("❌ Error en login: $e");
      return {"ok": false, "detail": "Error de conexión"};
    }
  }

  // ---------------------------------------------------------------
  // REGISTRO PACIENTE (ACTUALIZADO CON SEXO Y FECHA)
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    String? dni,
    String? telefono,
    String? pais,
    String? provincia,
    String? localidad,
    required String fechaNacimiento,
    required String sexo,
    bool aceptoCondiciones = true,
    String versionTexto = "v1.0",
  }) async {
    try {
      final body = {
        'full_name': name,
        'email': email,
        'password': password,
        'dni': dni,
        'telefono': telefono,
        'pais': pais,
        'provincia': provincia,
        'localidad': localidad,
        'fecha_nacimiento': fechaNacimiento,
        'sexo': sexo,
        'acepto_condiciones': aceptoCondiciones,
        'version_texto': versionTexto,
      };

      final res = await http
          .post(
            Uri.parse('$BASE_URL/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      print("📥 REGISTER STATUS: ${res.statusCode}");
      print("📥 REGISTER BODY: ${res.body}");

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          "ok": true,
          "mensaje": data["mensaje"] ??
              "Registro exitoso. Revisa tu correo para activar tu cuenta.",
          "user_id": data["user_id"]?.toString(),
          "full_name": data["full_name"],
          "role": data["role"] ?? "patient",
        };
      }

      return {"ok": false, "detail": data["detail"] ?? "No se pudo registrar."};
    } catch (e) {
      print("❌ Error en register: $e");
      return {"ok": false, "detail": "Error de conexión"};
    }
  }

  // ---------------------------------------------------------------
  // LOGIN CON GOOGLE
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>?> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: GOOGLE_IOS_CLIENT_ID,
        serverClientId: GOOGLE_SERVER_CLIENT_ID,
      );

      final account = await googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) return null;

      final res = await http
          .post(
            Uri.parse('$BASE_URL/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(_requestTimeout);

      print("📥 GOOGLE LOGIN STATUS: ${res.statusCode}");
      print("📥 GOOGLE LOGIN BODY: ${res.body}");

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "ok": true,
          "access_token": data['access_token'],
          "user_id": data['user']?['id']?.toString(),
          "full_name": data['user']?['full_name'] ?? "Usuario",
          "email": data['user']?['email'] ?? account.email,
          "perfil_completo": data['perfil_completo'] == true ||
              data['user']?['perfil_completo'] == true,
        };
      } else {
        return {
          "ok": false,
          "detail": data["detail"] ?? "No se pudo iniciar sesión con Google."
        };
      }
    } on TimeoutException {
      print("❌ Error loginWithGoogle: timeout");
      return {
        "ok": false,
        "detail":
            "El servidor tardó demasiado en responder. Intentá nuevamente en unos segundos."
      };
    } catch (e) {
      print("❌ Error loginWithGoogle: $e");
      return {"ok": false, "detail": "Error de conexión"};
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      final res = await http.get(Uri.parse('$BASE_URL/users/$userId'));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> completeProfile({
    required String userId,
    required String telefono,
    required String tipoDocumento,
    required String numeroDocumento,
    required String direccion,
    required String fechaNacimientoIso,
    required String sexo,
    required bool aceptaTerminos,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$BASE_URL/completar_perfil'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'telefono': telefono,
              'tipo_documento': tipoDocumento,
              'numero_documento': numeroDocumento,
              'direccion': direccion,
              'fecha_nacimiento': fechaNacimientoIso,
              'sexo': sexo,
              'acepta_terminos': aceptaTerminos,
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {
          'ok': true,
          'perfil_completo': data['perfil_completo'] == true,
          'user': data['user'],
        };
      }

      return {
        'ok': false,
        'detail': data['detail'] ?? 'No se pudo completar el perfil.',
      };
    } catch (e) {
      return {
        'ok': false,
        'detail': 'Error de conexión',
      };
    }
  }
}
