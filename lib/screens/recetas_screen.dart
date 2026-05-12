import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class RecetasScreen extends StatefulWidget {
  final String pacienteUuid;
  final String token;

  const RecetasScreen({
    super.key,
    required this.pacienteUuid,
    required this.token,
  });

  @override
  State<RecetasScreen> createState() => _RecetasScreenState();
}

class _RecetasScreenState extends State<RecetasScreen>
    with SingleTickerProviderStateMixin {
  static const Color kPrimary = Color(0xFF14B8A6);
  static const Duration _argentinaOffset = Duration(hours: -3);

  bool loading = true;
  String? errorMessage;
  List<dynamic> recetas = [];
  List<dynamic> certificados = [];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarArchivos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarArchivos() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/pacientes/${widget.pacienteUuid}/archivos",
      );

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer ${widget.token}"},
      );

      if (response.statusCode != 200) {
        throw Exception("Error ${response.statusCode}");
      }

      final decoded = json.decode(response.body);
      final archivos = _normalizarArchivos(decoded);

      final recetasFiltradas = <dynamic>[];
      final certificadosFiltrados = <dynamic>[];

      for (final archivo in archivos) {
        if (_esReceta(archivo)) {
          recetasFiltradas.add(archivo);
        }
        if (_esCertificado(archivo)) {
          certificadosFiltrados.add(archivo);
        }
      }

      if (!mounted) return;

      setState(() {
        recetas = recetasFiltradas;
        certificados = certificadosFiltrados;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error cargando archivos: $e");
      if (!mounted) return;
      setState(() {
        errorMessage = "No pudimos cargar tus documentos.";
        loading = false;
      });
    }
  }

  List<dynamic> _normalizarArchivos(dynamic decoded) {
    List<dynamic> rawList;

    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawList = (decoded["archivos"] ??
          decoded["documentos"] ??
          decoded["results"] ??
          []) as List<dynamic>;
    } else {
      rawList = [];
    }

    final archivos = <dynamic>[];

    for (final item in rawList) {
      if (item is Map) {
        archivos.add(
          Map<String, dynamic>.from(
            item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
        );
      }
    }

    archivos.sort((a, b) => _fechaDocumento(b).compareTo(_fechaDocumento(a)));

    return archivos;
  }

  DateTime _fechaDocumento(Map<String, dynamic> data) {
    return _parseFechaArgentina(
          _readString(data, [
            "fecha",
            "created_at",
            "fecha_emision",
            "emitido_en",
            "updated_at",
          ]),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _esReceta(dynamic archivo) {
    if (archivo is! Map) return false;
    final data = Map<String, dynamic>.from(
      archivo.map((key, value) => MapEntry(key.toString(), value)),
    );
    final tipo =
        _readString(data, ["tipo", "categoria", "document_type"]).toLowerCase();
    return tipo.contains("receta") || tipo.contains("prescripcion");
  }

  bool _esCertificado(dynamic archivo) {
    if (archivo is! Map) return false;
    final data = Map<String, dynamic>.from(
      archivo.map((key, value) => MapEntry(key.toString(), value)),
    );
    final tipo =
        _readString(data, ["tipo", "categoria", "document_type"]).toLowerCase();
    return tipo.contains("certificado");
  }

  List<dynamic> _filtrarDocumentos(List<dynamic> source) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((archivoRaw) {
      if (archivoRaw is! Map) return false;
      final archivo = Map<String, dynamic>.from(
        archivoRaw.map((key, value) => MapEntry(key.toString(), value)),
      );
      final haystack = [
        _readString(archivo, ["tipo", "categoria", "document_type"]),
        _readString(archivo, ["doctor", "medico", "profesional", "autor"]),
        _readString(archivo, ["medicamento", "diagnostico", "motivo"]),
        _readString(archivo, ["descripcion", "detalle", "indicacion"]),
        _formatFechaArgentina(
          _readString(archivo, [
            "fecha",
            "created_at",
            "fecha_emision",
            "emitido_en",
            "updated_at",
          ]),
        ),
      ].join(" ").toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return "";
  }

  DateTime? _parseFechaArgentina(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final numeric = int.tryParse(text);
    if (numeric != null) {
      final millis = text.length <= 10 ? numeric * 1000 : numeric;
      return _toArgentinaWallTime(
        DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
      );
    }

    final normalized = text.replaceFirst(' ', 'T');
    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(normalized);
    if (hasTimezone) {
      final parsed = DateTime.tryParse(normalized);
      if (parsed == null) return null;
      return _toArgentinaWallTime(parsed);
    }

    final iso = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?',
    ).firstMatch(text);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
        int.tryParse(iso.group(4) ?? '0') ?? 0,
        int.tryParse(iso.group(5) ?? '0') ?? 0,
        int.tryParse(iso.group(6) ?? '0') ?? 0,
      );
    }

    final ar = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?',
    ).firstMatch(text);
    if (ar != null) {
      return DateTime(
        int.parse(ar.group(3)!),
        int.parse(ar.group(2)!),
        int.parse(ar.group(1)!),
        int.tryParse(ar.group(4) ?? '0') ?? 0,
        int.tryParse(ar.group(5) ?? '0') ?? 0,
        int.tryParse(ar.group(6) ?? '0') ?? 0,
      );
    }

    final parsed = DateTime.tryParse(normalized);
    return parsed == null ? null : _toArgentinaWallTime(parsed);
  }

  DateTime _toArgentinaWallTime(DateTime value) {
    final argentina = value.toUtc().add(_argentinaOffset);
    return DateTime(
      argentina.year,
      argentina.month,
      argentina.day,
      argentina.hour,
      argentina.minute,
      argentina.second,
    );
  }

  String _formatFechaArgentina(dynamic raw) {
    final original = raw?.toString().trim() ?? "";
    final parsed = _parseFechaArgentina(original);
    if (parsed == null) return original;

    String two(int n) => n.toString().padLeft(2, '0');
    final fecha = "${two(parsed.day)}/${two(parsed.month)}/${parsed.year}";
    final tieneHora = RegExp(r'\d{1,2}:\d{2}').hasMatch(original);
    if (!tieneHora) return fecha;
    return "$fecha ${two(parsed.hour)}:${two(parsed.minute)}";
  }

  Future<void> _abrirDocumento(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Documento no disponible")),
      );
      return;
    }

    final uri = _resolverUriDocumento(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: kPrimary,
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 16),
            Text(
              "Abriendo documento...",
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception("No se pudo abrir el navegador");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al abrir el documento: $e")),
      );
    }
  }

  Future<void> _compartirDocumentoWhatsApp(String? url, bool esReceta) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Documento no disponible")),
      );
      return;
    }

    final docUrl = _resolverUriDocumento(url).toString();
    final tipo = esReceta ? "receta" : "certificado";
    final mensaje = Uri.encodeComponent(
      "Hola, te comparto mi $tipo de DocYa:\n$docUrl",
    );
    final whatsapp = Uri.parse("https://wa.me/?text=$mensaje");

    try {
      final launched = await launchUrl(
        whatsapp,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception("No se pudo abrir WhatsApp");
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al compartir por WhatsApp: $e")),
      );
    }
  }

  Uri _resolverUriDocumento(String rawUrl) {
    final uri = Uri.parse(rawUrl);
    final path = uri.path;
    final recetaMatch =
        RegExp(r'^/recetario/recetas/(\d+)/html$').firstMatch(path);
    if (recetaMatch != null) {
      final recetaId = recetaMatch.group(1)!;
      return Uri.parse(
        'https://docya-railway-production.up.railway.app/pacientes/${widget.pacienteUuid}/recetario/recetas/$recetaId',
      );
    }

    final certificadoMatch =
        RegExp(r'^/recetario/certificados/(\d+)/html$').firstMatch(path);
    if (certificadoMatch != null) {
      final certId = certificadoMatch.group(1)!;
      return Uri.parse(
        'https://docya-railway-production.up.railway.app/pacientes/${widget.pacienteUuid}/recetario/certificados/$certId',
      );
    }

    return uri;
  }

  Widget _glassCard(
    BuildContext context, {
    required Widget child,
    EdgeInsets? padding,
    double radius = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : kPrimary.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
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

  Widget _emptyState(BuildContext context, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Center(
            child: _glassCard(
              context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    color: isDark ? Colors.white30 : Colors.black26,
                    size: 56,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black45,
                      fontSize: 13.5,
                      height: 1.4,
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

  Widget _documentCard(dynamic archivoRaw, bool isDark) {
    final archivo = Map<String, dynamic>.from(
      (archivoRaw as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    final tipo =
        _readString(archivo, ["tipo", "categoria", "document_type"]).isNotEmpty
            ? _readString(archivo, ["tipo", "categoria", "document_type"])
            : "Documento clínico";
    final doctor =
        _readString(archivo, ["doctor", "medico", "profesional", "autor"]);
    final fechaRaw = _readString(archivo, [
      "fecha",
      "created_at",
      "fecha_emision",
      "emitido_en",
      "updated_at",
    ]);
    final fecha = _formatFechaArgentina(fechaRaw);
    final url = _readString(archivo, ["url", "archivo_url", "documento_url"]);
    final esReceta = _esReceta(archivo);
    final accent = esReceta ? kPrimary : const Color(0xFF7C3AED);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accent.withOpacity(isDark ? 0.18 : 0.12),
                  ),
                  child: Icon(
                    esReceta
                        ? Icons.receipt_long_rounded
                        : Icons.assignment_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tipo,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        esReceta
                            ? "Documento médico emitido para el paciente"
                            : "Certificado clínico disponible para descarga",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    esReceta ? "Receta" : "Certificado",
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (doctor.isNotEmpty)
                  _metaChip(
                    icon: Icons.person_outline_rounded,
                    label: doctor,
                    accent: accent,
                    isDark: isDark,
                  ),
                if (fecha.isNotEmpty)
                  _metaChip(
                    icon: Icons.calendar_month_rounded,
                    label: fecha,
                    accent: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.92),
                          accent.withOpacity(0.74),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _abrirDocumento(url),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Abrir",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _compartirDocumentoWhatsApp(url, esReceta),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366)
                            .withOpacity(isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF25D366).withOpacity(0.26),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            color: Color(0xFF16A34A),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "WhatsApp",
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color accent,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF7FBFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(isDark ? 0.18 : 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<dynamic> archivos, bool isDark) {
    final filtered = _filtrarDocumentos(archivos);
    if (archivos.isEmpty) {
      return _emptyState(
        context,
        "No hay documentos disponibles",
        "Cuando tu profesional emita recetas o certificados, los vas a ver acá.",
      );
    }

    if (filtered.isEmpty) {
      return _emptyState(
        context,
        "No encontramos documentos",
        "Proba buscar por profesional, medicamento, diagnostico o fecha.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: filtered.length + 1,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == 0) return _safeInfoCard(isDark);
        return _documentCard(filtered[index - 1], isDark);
      },
    );
  }

  Widget _safeInfoCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    const Color(0xFF083C3A).withOpacity(0.70),
                    Colors.white.withOpacity(0.05),
                  ]
                : [
                    const Color(0xFFE8FAF7),
                    const Color(0xFFF8FCFC),
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : kPrimary.withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: kPrimary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tus documentos estan seguros",
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Recetas y certificados ordenados por fecha Argentina.",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF04151C) : const Color(0xFFF5F7F8),
        body: const Center(
          child: CircularProgressIndicator(color: kPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF04151C) : const Color(0xFFF5F7F8),
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(
              left: -120,
              top: 60,
              child: IgnorePointer(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromRGBO(20, 184, 166, 0.18),
                        Color.fromRGBO(20, 184, 166, 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -140,
              top: 210,
              child: IgnorePointer(
                child: Container(
                  width: 330,
                  height: 330,
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: _glassCard(
                    context,
                    radius: 28,
                    padding: const EdgeInsets.all(22),
                    child: Column(
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
                                    color: kPrimary.withOpacity(0.24),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.folder_copy_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimary.withOpacity(
                                        isDark ? 0.16 : 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      "Documentación clínica",
                                      style: TextStyle(
                                        color: kPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Mis documentos",
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Acá podés ver y abrir los documentos emitidos para el paciente. La información se separa entre recetas y certificados para que sea más fácil encontrar cada archivo.",
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color:
                              isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  "Buscar receta, certificado o medico...",
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                            icon: const Icon(Icons.close_rounded),
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : kPrimary.withOpacity(0.08),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0EA896),
                            Color(0xFF14B8A6),
                          ],
                        ),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor:
                          isDark ? Colors.white70 : Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                      tabs: [
                        Tab(text: "Recetas (${recetas.length})"),
                        Tab(text: "Certificados (${certificados.length})"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListView(recetas, isDark),
                      _buildListView(certificados, isDark),
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
}
