import 'package:flutter/material.dart';

Widget statusBanner({
  required bool enCamino,
  required String rutaLabel,
  required int asientosOcupados,
  required int capacidad,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: enCamino
          ? const LinearGradient(
          colors: [Color(0xFF1E6BFF), Color(0xFF0A4BCC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight)
          : const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(
              enCamino
                  ? Icons.directions_car_rounded
                  : Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 26),
          const SizedBox(width: 10),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
                enCamino ? 'EN CAMINO' : 'ESPERANDO PASAJEROS',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 12),
        Text('$asientosOcupados de $capacidad asientos ocupados',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: capacidad > 0 ? asientosOcupados / capacidad : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor:
              const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            )),
      ],
    ),
  );
}