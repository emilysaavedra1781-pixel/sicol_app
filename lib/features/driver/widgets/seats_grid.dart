import 'package:flutter/material.dart';

Widget seatsGrid({
  required Map<String, dynamic> asientos,
  required int capacidad,
}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: capacidad,
      itemBuilder: (context, index) {
        final key = 'asiento_${index + 1}';
        final asiento = (asientos[key] as Map?)?.cast<String, dynamic>() ?? {};
        final estado = asiento['estado'] ?? 'libre';

        Color color;
        IconData icon;

        if (estado == 'ocupado') {
          color = const Color(0xFFF59E0B); // Naranja (pago confirmado)
          icon = Icons.person;
        } else if (estado == 'abordado') {
          color = const Color(0xFF10B981); // Verde (ya subió)
          icon = Icons.check_circle;
        } else if (estado == 'bloqueado') {
          color = const Color(0xFFFFD60A); // Amarillo (proceso de pago)
          icon = Icons.lock_clock_rounded;
        } else {
          color = const Color(0xFFE5E7EB); // Gris (libre)
          icon = Icons.event_seat_rounded;
        }

        return Container(
          decoration: BoxDecoration(
            color: estado == 'libre' ? const Color(0xFFF9FAFB) : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: estado == 'libre' ? const Color(0xFFE5E7EB) : color),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: estado == 'libre' ? const Color(0xFFD1D5DB) : color, size: 24),
              const SizedBox(height: 4),
              Text('${index + 1}',
                  style: TextStyle(
                      color: estado == 'libre' ? const Color(0xFF9CA3AF) : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    ),
  );
}
