import 'package:flutter/material.dart';

Widget adminAlert() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B)),
    ),
    child: const Row(children: [
      Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF59E0B), size: 20),
      SizedBox(width: 12),
      Expanded(
          child: Text(
              'EL ADMINISTRADOR FORZÓ EL ARRANQUE',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
    ]),
  );
}

Widget sinPasajeros() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: Colors.grey[300], size: 50),
          const SizedBox(height: 16),
          const Text('SIN PASAJEROS AÚN',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ],
      ),
    ),
  );
}
