import 'package:flutter/material.dart';

Widget statusBanner({
  required bool enCamino,
  required String rutaLabel,
  required int asientosOcupados,
  required int capacidad,
}) {
  final primaryColor = enCamino ? const Color(0xFF7C3AED) : const Color(0xFF10B981);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: primaryColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              enCamino ? 'VIAJE EN CURSO' : 'ESPERANDO RECOJO',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5),
            ),
            const Icon(Icons.info_outline, color: Colors.white70, size: 16),
          ],
        ),
        const SizedBox(height: 12),
        Text('$asientosOcupados de $capacidad pasajeros',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: capacidad > 0 ? asientosOcupados / capacidad : 0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            )),
      ],
    ),
  );
}
