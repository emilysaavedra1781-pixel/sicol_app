import 'package:flutter/material.dart';

Widget seatsGrid({
  required Map<String, dynamic> asientos,
  required int capacidad,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF1F2937)),
    ),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: capacidad,
      itemBuilder: (context, index) {
        final key = 'asiento_${index + 1}';
        final asiento =
            (asientos[key] as Map?)?.cast<String, dynamic>() ?? {};
        final estado = asiento['estado'] ?? 'libre';

        Color color;
        IconData icon;

        if (estado == 'ocupado') {
          color = const Color(0xFFF59E0B);
          icon = Icons.person;
        } else if (estado == 'abordado') {
          color = const Color(0xFF10B981);
          icon = Icons.check_circle;
        } else if (estado == 'bloqueado') {
          color = const Color(0xFFFF3B30);
          icon = Icons.lock_outline;
        } else {
          color = const Color(0xFF6B7280);
          icon = Icons.person_outline;
        }

        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text('${index + 1}',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    ),
  );
}