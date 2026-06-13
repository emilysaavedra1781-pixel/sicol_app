import 'package:flutter/material.dart';

Widget adminAlert() {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
    ),
    child: const Row(children: [
      Icon(Icons.admin_panel_settings_rounded,
          color: Color(0xFFF59E0B), size: 20),
      SizedBox(width: 10),
      Expanded(
          child: Text(
              'El administrador forzó el arranque de este viaje.',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13))),
    ]),
  );
}

Widget sinPasajeros() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937))),
    child: const Column(children: [
      Icon(Icons.people_outline, color: Color(0xFF6B7280), size: 40),
      SizedBox(height: 10),
      Text('Sin pasajeros aún',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
    ]),
  );
}