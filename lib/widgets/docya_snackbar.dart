import 'package:flutter/material.dart';

enum SnackType { success, error, info, warning }

class DocYaSnackbar {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    SnackType type = SnackType.success,
  }) {
    // Colores e íconos por tipo
    Color startColor;
    Color endColor;
    IconData icon;

    switch (type) {
      case SnackType.success:
        startColor = const Color(0xFF14B8A6);
        endColor = const Color(0xFF0F2027);
        icon = Icons.check_circle_rounded;
        break;
      case SnackType.error:
        startColor = Colors.redAccent;
        endColor = const Color(0xFF2C5364);
        icon = Icons.error_rounded;
        break;
      case SnackType.info:
        startColor = Colors.blueAccent;
        endColor = const Color(0xFF2C5364);
        icon = Icons.info_rounded;
        break;
      case SnackType.warning:
        startColor = Colors.amber;
        endColor = const Color(0xFF2C5364);
        icon = Icons.warning_amber_rounded;
        break;
    }

    final snackBar = SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
