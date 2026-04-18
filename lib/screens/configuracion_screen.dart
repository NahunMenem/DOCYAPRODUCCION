import 'package:flutter/material.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Configuración"),
        backgroundColor: const Color(0xFF11B5B0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _itemConfig(
            context,
            icon: Icons.person_outline,
            titulo: "Editar perfil",
            subtitulo: "Actualiza tu nombre, teléfono o dirección",
            onTap: () {
              // TODO: Navegar a EditarPerfilScreen
            },
          ),
          _itemConfig(
            context,
            icon: Icons.lock_outline,
            titulo: "Cambiar contraseña",
            subtitulo: "Modifica tu contraseña de acceso",
            onTap: () {
              // TODO: Navegar a CambiarPasswordScreen
            },
          ),
          _itemConfig(
            context,
            icon: Icons.notifications_active_outlined,
            titulo: "Notificaciones",
            subtitulo: "Activa o desactiva notificaciones",
            onTap: () {
              // TODO: Navegar a NotificacionesScreen
            },
          ),
          _itemConfig(
            context,
            icon: Icons.language,
            titulo: "Idioma",
            subtitulo: "Selecciona tu idioma preferido",
            onTap: () {
              // TODO: Navegar a IdiomaScreen
            },
          ),
          _itemConfig(
            context,
            icon: Icons.health_and_safety_outlined,
            titulo: "Preferencias médicas",
            subtitulo: "Alergias, condiciones importantes",
            onTap: () {
              // TODO: Navegar a PreferenciasMedicasScreen
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // ⚡ Cerrar sesión
              Navigator.pushReplacementNamed(context, "/login");
            },
            icon: const Icon(Icons.logout),
            label: const Text("Cerrar sesión",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _itemConfig(BuildContext context,
      {required IconData icon,
      required String titulo,
      String? subtitulo,
      required VoidCallback onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF11B5B0), size: 28),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: subtitulo != null
            ? Text(subtitulo, style: const TextStyle(color: Colors.black54))
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
