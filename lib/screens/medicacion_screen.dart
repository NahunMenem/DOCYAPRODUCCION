import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/medication_reminder_service.dart';
import '../services/medication_service.dart';
import '../widgets/docya_snackbar.dart';

class MedicacionScreen extends StatefulWidget {
  final String pacienteUuid;

  const MedicacionScreen({
    super.key,
    required this.pacienteUuid,
  });

  @override
  State<MedicacionScreen> createState() => _MedicacionScreenState();
}

class _MedicacionScreenState extends State<MedicacionScreen> {
  static const Color _primary = Color(0xFF14B8A6);

  bool _loading = true;
  bool _notificationPermissionGranted = true;
  bool _notificationPermissionChecked = false;
  List<Map<String, dynamic>> _today = [];
  List<Map<String, dynamic>> _agenda = [];
  List<Map<String, dynamic>> _medicaciones = [];
  Map<String, dynamic> _historial = const {};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor =>
      _isDark ? const Color(0xFF04151C) : const Color(0xFFF5FBFA);
  Color get _cardColor =>
      _isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.94);
  Color get _cardBorderColor =>
      _isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.08);
  Color get _surfaceSoftColor =>
      _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFECF7F5);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF102027);
  Color get _textSecondary =>
      _isDark ? Colors.white70 : const Color(0xFF5F6F76);
  Color get _textMuted => _isDark ? Colors.white60 : const Color(0xFF7C8B92);
  Color get _outlineColor =>
      _isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.10);

  bool _hasImmediateReminderForToday(
    DateTime fecha,
    List<TimeOfDay> horarios,
  ) {
    final now = DateTime.now();
    final selectedDay = DateTime(fecha.year, fecha.month, fecha.day);
    final today = DateTime(now.year, now.month, now.day);
    if (selectedDay != today) return false;

    for (final horario in horarios) {
      final scheduled = DateTime(
        fecha.year,
        fecha.month,
        fecha.day,
        horario.hour,
        horario.minute,
      );
      if (!scheduled.isAfter(now)) {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _ensureNotificationPermission();
    await _load();
  }

  bool _isNotificationPermissionAccepted(PermissionStatus status) {
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  Future<void> _ensureNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!_isNotificationPermissionAccepted(status) &&
        !status.isPermanentlyDenied) {
      status = await Permission.notification.request();
    }

    if (!mounted) return;
    setState(() {
      _notificationPermissionGranted =
          _isNotificationPermissionAccepted(status);
      _notificationPermissionChecked = true;
    });
  }

  Future<void> _openNotificationSettings() async {
    await openAppSettings();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MedicationService.getTodayDoses(widget.pacienteUuid),
        MedicationService.getAgenda(widget.pacienteUuid, dias: 30),
        MedicationService.getMedicaciones(widget.pacienteUuid),
        MedicationService.getHistorial(widget.pacienteUuid),
      ]);

      final today = results[0] as List<Map<String, dynamic>>;
      final agenda = results[1] as List<Map<String, dynamic>>;
      final medicaciones = (results[2] as List<Map<String, dynamic>>)
          .where((item) => item['activa'] != false)
          .toList();
      final historial = results[3] as Map<String, dynamic>;

      await MedicationReminderService.syncAgenda(agenda);

      if (!mounted) return;
      setState(() {
        _today = today;
        _agenda = agenda;
        _medicaciones = medicaciones;
        _historial = historial;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      DocYaSnackbar.show(
        context,
        title: 'No pudimos cargar tu medicación',
        message: '$e',
        type: SnackType.error,
      );
    }
  }

  Future<void> _updateDose(int tomaId, String estado) async {
    try {
      await MedicationService.updateDose(tomaId, estado);
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: estado == 'tomado' ? 'Toma registrada' : 'Toma omitida',
        message: estado == 'tomado'
            ? 'Guardamos esta toma en tu historial.'
            : 'La dejamos marcada como omitida para tu seguimiento.',
        type: SnackType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'No pudimos actualizar la toma',
        message: '$e',
        type: SnackType.error,
      );
    }
  }

  Future<void> _addMedication() async {
    if (!_notificationPermissionGranted) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'Activa las notificaciones',
        message:
            'Necesitas habilitar las notificaciones para usar los recordatorios de medicacion correctamente.',
        type: SnackType.error,
      );
      return;
    }

    final nombreCtrl = TextEditingController();
    final dosisCtrl = TextEditingController();
    final frecuenciaCtrl = TextEditingController();
    final observacionesCtrl = TextEditingController();
    final horarios = <TimeOfDay>[];
    DateTime fechaInicio = DateTime.now();
    DateTime? fechaFin;

    Future<void> pickTime(StateSetter setModal) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked == null) return;
      setModal(() {
        final exists = horarios.any(
          (item) => item.hour == picked.hour && item.minute == picked.minute,
        );
        if (!exists) {
          horarios.add(picked);
          horarios.sort(
            (a, b) =>
                (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
          );
        }
      });
    }

    Future<void> pickDate(StateSetter setModal, bool end) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: end ? (fechaFin ?? fechaInicio) : fechaInicio,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked == null) return;
      setModal(() {
        if (end) {
          fechaFin = picked;
        } else {
          fechaInicio = picked;
          if (fechaFin != null && fechaFin!.isBefore(fechaInicio)) {
            fechaFin = fechaInicio;
          }
        }
      });
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _glass(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agregar medicación',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'DocYa programará recordatorios automáticos con estos horarios.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      _sheetInput(
                        nombreCtrl,
                        'Medicamento',
                        hintText: 'Ej: Amoxicilina 500 mg',
                      ),
                      const SizedBox(height: 12),
                      _sheetInput(
                        dosisCtrl,
                        'Dosis',
                        hintText: 'Ej: 1 comprimido',
                      ),
                      const SizedBox(height: 12),
                      _sheetInput(
                        frecuenciaCtrl,
                        'Frecuencia',
                        hintText: 'Ej: Cada 8 horas',
                      ),
                      const SizedBox(height: 12),
                      _sheetInput(
                        observacionesCtrl,
                        'Observaciones',
                        maxLines: 3,
                        hintText: 'Ej: Tomar después de comer',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _dateSelector(
                              'Inicio',
                              DateFormat('dd/MM/yyyy').format(fechaInicio),
                              () => pickDate(setModal, false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dateSelector(
                              'Fin',
                              fechaFin == null
                                  ? 'Sin fecha'
                                  : DateFormat('dd/MM/yyyy').format(fechaFin!),
                              () => pickDate(setModal, true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Horarios',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => pickTime(setModal),
                            icon: const Icon(Icons.add_alarm_rounded),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: horarios
                            .map(
                              (h) => Chip(
                                label: Text(h.format(context)),
                                onDeleted: () =>
                                    setModal(() => horarios.remove(h)),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (created != true) return;

    if (nombreCtrl.text.trim().isEmpty ||
        dosisCtrl.text.trim().isEmpty ||
        horarios.isEmpty) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'Faltan datos',
        message: 'Completa nombre, dosis y al menos un horario.',
        type: SnackType.warning,
      );
      return;
    }

    try {
      final immediateReminder =
          _hasImmediateReminderForToday(fechaInicio, horarios);
      await MedicationService.createMedication(
        pacienteUuid: widget.pacienteUuid,
        nombre: nombreCtrl.text.trim(),
        dosis: dosisCtrl.text.trim(),
        frecuencia: frecuenciaCtrl.text.trim().isEmpty
            ? null
            : frecuenciaCtrl.text.trim(),
        observaciones: observacionesCtrl.text.trim().isEmpty
            ? null
            : observacionesCtrl.text.trim(),
        fechaInicio: DateFormat('yyyy-MM-dd').format(fechaInicio),
        fechaFin: fechaFin == null
            ? null
            : DateFormat('yyyy-MM-dd').format(fechaFin!),
        horarios: horarios
            .map(
              (h) =>
                  '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}:00',
            )
            .toList(),
      );

      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'Medicacion guardada',
        message: immediateReminder
            ? 'Tu plan quedó cargado. Como elegiste una hora de ahora o ya pasada hoy, el primer aviso puede sonar en unos segundos.'
            : 'Tu plan quedó cargado con recordatorios automáticos.',
        type: SnackType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'No pudimos guardar la medicación',
        message: '$e',
        type: SnackType.error,
      );
    }
  }

  Future<void> _editMedication(Map<String, dynamic> medication) async {
    final nombreCtrl = TextEditingController(
      text: (medication['nombre'] ?? '').toString(),
    );
    final dosisCtrl = TextEditingController(
      text: (medication['dosis'] ?? '').toString(),
    );
    final frecuenciaCtrl = TextEditingController(
      text: (medication['frecuencia'] ?? '').toString(),
    );
    final observacionesCtrl = TextEditingController(
      text: (medication['observaciones'] ?? '').toString(),
    );
    final horarios = <TimeOfDay>[];
    for (final item in ((medication['horarios'] as List?) ?? const [])) {
      final parts = item.toString().split(':');
      if (parts.length >= 2) {
        horarios.add(
          TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          ),
        );
      }
    }

    DateTime fechaInicio =
        DateTime.tryParse((medication['fecha_inicio'] ?? '').toString()) ??
            DateTime.now();
    DateTime? fechaFin =
        DateTime.tryParse((medication['fecha_fin'] ?? '').toString());

    Future<void> pickTime(StateSetter setModal) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: horarios.isNotEmpty ? horarios.first : TimeOfDay.now(),
      );
      if (picked == null) return;
      setModal(() {
        final exists = horarios.any(
          (item) => item.hour == picked.hour && item.minute == picked.minute,
        );
        if (!exists) {
          horarios.add(picked);
          horarios.sort(
            (a, b) =>
                (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
          );
        }
      });
    }

    Future<void> pickDate(StateSetter setModal, bool end) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: end ? (fechaFin ?? fechaInicio) : fechaInicio,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked == null) return;
      setModal(() {
        if (end) {
          fechaFin = picked;
        } else {
          fechaInicio = picked;
          if (fechaFin != null && fechaFin!.isBefore(fechaInicio)) {
            fechaFin = fechaInicio;
          }
        }
      });
    }

    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _glass(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Editar medicación',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Actualiza los datos y recalcularemos las próximas tomas.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      _sheetInput(
                        nombreCtrl,
                        'Medicamento',
                        hintText: 'Ej: Amoxicilina 500 mg',
                      ),
                      const SizedBox(height: 12),
                      _sheetInput(
                        dosisCtrl,
                        'Dosis',
                        hintText: 'Ej: 1 comprimido',
                      ),
                      const SizedBox(height: 12),
                      _sheetInput(
                        frecuenciaCtrl,
                        'Frecuencia',
                        hintText: 'Ej: Cada 8 horas',
                      ),
                      const SizedBox(height: 12),
                      _sheetInput(
                        observacionesCtrl,
                        'Observaciones',
                        maxLines: 3,
                        hintText: 'Ej: Tomar después de comer',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _dateSelector(
                              'Inicio',
                              DateFormat('dd/MM/yyyy').format(fechaInicio),
                              () => pickDate(setModal, false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dateSelector(
                              'Fin',
                              fechaFin == null
                                  ? 'Sin fecha'
                                  : DateFormat('dd/MM/yyyy').format(fechaFin!),
                              () => pickDate(setModal, true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Horarios',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => pickTime(setModal),
                            icon: const Icon(Icons.add_alarm_rounded),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: horarios
                            .map(
                              (h) => Chip(
                                label: Text(h.format(context)),
                                onDeleted: () =>
                                    setModal(() => horarios.remove(h)),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Guardar cambios'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (edited != true) return;

    if (nombreCtrl.text.trim().isEmpty ||
        dosisCtrl.text.trim().isEmpty ||
        horarios.isEmpty) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'Faltan datos',
        message: 'Completa nombre, dosis y al menos un horario.',
        type: SnackType.warning,
      );
      return;
    }

    try {
      final immediateReminder =
          _hasImmediateReminderForToday(fechaInicio, horarios);
      await MedicationService.editMedication(
        medicacionId: medication['id'] as int,
        pacienteUuid: widget.pacienteUuid,
        nombre: nombreCtrl.text.trim(),
        dosis: dosisCtrl.text.trim(),
        frecuencia: frecuenciaCtrl.text.trim().isEmpty
            ? null
            : frecuenciaCtrl.text.trim(),
        observaciones: observacionesCtrl.text.trim().isEmpty
            ? null
            : observacionesCtrl.text.trim(),
        fechaInicio: DateFormat('yyyy-MM-dd').format(fechaInicio),
        fechaFin: fechaFin == null
            ? null
            : DateFormat('yyyy-MM-dd').format(fechaFin!),
        horarios: horarios
            .map(
              (h) =>
                  '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}:00',
            )
            .toList(),
      );

      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'Medicacion actualizada',
        message: immediateReminder
            ? 'Recalculamos las próximas tomas. Si el horario era para ahora o ya pasó hoy, el primer aviso puede sonar en unos segundos.'
            : 'Recalculamos las próximas tomas con los nuevos datos.',
        type: SnackType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'No pudimos editar la medicación',
        message: '$e',
        type: SnackType.error,
      );
    }
  }

  Future<void> _deleteMedication(Map<String, dynamic> medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar medicación'),
        content: Text(
          'Se desactivará ${(medication['nombre'] ?? 'esta medicación').toString()} y se borrarán sus próximas tomas pendientes. El historial ya registrado se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await MedicationService.deleteMedication(medication['id'] as int);
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'Medicacion eliminada',
        message:
            'Desactivamos el plan y quitamos las próximas tomas pendientes.',
        type: SnackType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      DocYaSnackbar.show(
        context,
        title: 'No pudimos eliminar la medicación',
        message: '$e',
        type: SnackType.error,
      );
    }
  }

  String _formatHour(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  String _formatDate(String raw) {
    try {
      return DateFormat('EEEE d MMM', 'es_AR')
          .format(DateTime.parse(raw))
          .replaceFirstMapped(
              RegExp(r'^[a-z]'), (m) => m.group(0)!.toUpperCase());
    } catch (_) {
      return raw;
    }
  }

  Widget _glass({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final resumen =
        Map<String, dynamic>.from(_historial['resumen'] as Map? ?? const {});
    final adherencia = (resumen['adherencia_pct'] ?? 0).toString();
    final tomadas = (resumen['tomadas'] ?? 0).toString();
    final pendientes = (resumen['pendientes'] ?? 0).toString();

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  PhosphorIconsFill.heartbeat,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu plan de medicación',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'DocYa te recuerda tus tomas aunque cierres la app.',
                      style: TextStyle(color: _textSecondary, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _metricTile('Adherencia', '$adherencia%')),
              const SizedBox(width: 10),
              Expanded(child: _metricTile('Tomadas', tomadas)),
              const SizedBox(width: 10),
              Expanded(child: _metricTile('Pendientes', pendientes)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permissionBanner() {
    if (!_notificationPermissionChecked || _notificationPermissionGranted) {
      return const SizedBox.shrink();
    }

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_off_rounded,
                color: Color(0xFFF59E0B),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Activa las notificaciones para usar el pastillero',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Sin permisos, podes ver tu medicacion pero los recordatorios pueden no sonar ni llegar correctamente en iPhone o Android.',
            style: TextStyle(color: _textSecondary, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await _ensureNotificationPermission();
                  if (!mounted) return;
                  if (_notificationPermissionGranted) {
                    DocYaSnackbar.show(
                      context,
                      title: 'Notificaciones activadas',
                      message:
                          'Ya podes recibir recordatorios de medicacion en este dispositivo.',
                      type: SnackType.success,
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Permitir notificaciones'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openNotificationSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Abrir ajustes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: BorderSide(color: _outlineColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceSoftColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _todaySection() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tomas de hoy',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirma si ya la tomaste o márcala como omitida para que tu historial quede correcto.',
            style: TextStyle(color: _textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          if (_today.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceSoftColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'No tienes tomas programadas para hoy.',
                style: TextStyle(color: _textSecondary),
              ),
            )
          else
            ..._today.map((toma) {
              final estado = (toma['estado'] ?? 'pendiente').toString();
              final canAct = estado == 'pendiente';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceSoftColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: estado == 'tomado'
                          ? Colors.greenAccent.withOpacity(0.24)
                          : estado == 'omitido'
                              ? Colors.orangeAccent.withOpacity(0.24)
                              : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (toma['nombre'] ?? 'Medicacion').toString(),
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            _formatHour(
                              (toma['horario_programado'] ?? '').toString(),
                            ),
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (toma['dosis'] ?? '').toString(),
                        style: TextStyle(color: _textSecondary),
                      ),
                      if ((toma['observaciones'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            (toma['observaciones'] ?? '').toString(),
                            style: TextStyle(color: _textMuted),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (!canAct)
                        Text(
                          estado == 'tomado'
                              ? 'Ya registraste esta toma.'
                              : 'Quedó marcada como omitida.',
                          style: TextStyle(
                            color: estado == 'tomado'
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _updateDose(toma['id'] as int, 'tomado'),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('La tomé'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _updateDose(toma['id'] as int, 'omitido'),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text('Omitir'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orangeAccent,
                                  side: BorderSide(
                                    color: Colors.orangeAccent.withOpacity(0.6),
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
            }),
        ],
      ),
    );
  }

  Widget _agendaSection() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _agenda) {
      final key = (item['fecha'] ?? '').toString();
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Próximos recordatorios',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (grouped.isEmpty)
            Text(
              'Todavía no hay recordatorios programados.',
              style: TextStyle(color: _textSecondary),
            )
          else
            ...grouped.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(entry.key),
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...entry.value.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_formatHour((item['horario_programado'] ?? '').toString())} • ${item['nombre']}',
                                style: TextStyle(color: _textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _medicationPlans() {
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planes activos',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (_medicaciones.isEmpty)
            Text(
              'Todavía no hay medicación cargada por tu profesional.',
              style: TextStyle(color: _textSecondary),
            )
          else
            ..._medicaciones.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceSoftColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (med['nombre'] ?? '').toString(),
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editMedication(med),
                            icon: Icon(
                              Icons.edit_outlined,
                              color: _textSecondary,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteMedication(med),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (med['dosis'] ?? '').toString(),
                        style: TextStyle(color: _textSecondary),
                      ),
                      if ((med['observaciones'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            (med['observaciones'] ?? '').toString(),
                            style: TextStyle(
                              color: _textMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(
                            (med['frecuencia'] ?? 'Según indicación')
                                .toString(),
                          ),
                          _chip(
                            'Inicio ${(med['fecha_inicio'] ?? '').toString()}',
                          ),
                          if ((med['fecha_fin'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            _chip(
                                'Hasta ${(med['fecha_fin'] ?? '').toString()}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceSoftColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: _textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _sheetInput(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: _textSecondary),
        hintStyle: TextStyle(color: _textMuted.withOpacity(0.7)),
        filled: true,
        fillColor: _surfaceSoftColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _cardBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _cardBorderColor),
        ),
      ),
    );
  }

  Widget _dateSelector(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surfaceSoftColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: _textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    final historial = (((_historial['historial']) as List?) ?? const [])
        .cast<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(8)
        .toList();

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historial reciente',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (historial.isEmpty)
            const Text(
              'Todavía no hay movimientos en tu historial.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...historial.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      (item['estado'] ?? 'pendiente') == 'tomado'
                          ? Icons.check_circle_rounded
                          : Icons.remove_circle_rounded,
                      color: (item['estado'] ?? 'pendiente') == 'tomado'
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['nombre'] ?? '').toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatDate((item['fecha'] ?? '').toString())} • ${_formatHour((item['horario_programado'] ?? '').toString())}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _textPrimary,
        title: Text(
          'Mi medicación',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _addMedication,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            right: -80,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primary.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              color: _primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _permissionBanner(),
                  if (_notificationPermissionChecked &&
                      !_notificationPermissionGranted)
                    const SizedBox(height: 16),
                  _summaryCard(),
                  const SizedBox(height: 16),
                  _todaySection(),
                  const SizedBox(height: 16),
                  _agendaSection(),
                  const SizedBox(height: 16),
                  _medicationPlans(),
                  const SizedBox(height: 16),
                  _historySection(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
