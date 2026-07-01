import 'package:flutter/material.dart';

Widget startButton({
  required bool estaLleno,
  required int asientosOcupados,
  required int capacidad,
  required bool todosAbordaron,
  required int pendientes,
  required bool arrancando,
  required VoidCallback onArrancar,
  required VoidCallback onVerificar,
}) {
  final bool puedeArrancar = estaLleno && todosAbordaron;

  return Column(
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStepRow('1. Colectivo lleno', estaLleno, Icons.groups_rounded),
              const Divider(height: 32),
              _buildStepRow('2. Códigos validados', todosAbordaron, Icons.qr_code_scanner_rounded),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: (arrancando || !puedeArrancar) ? null : onArrancar,
        icon: arrancando 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.play_arrow_rounded),
        label: Text(arrancando ? 'ARRANCANDO...' : 'ARRANCAR VIAJE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          disabledBackgroundColor: const Color(0xFFE5E7EB),
        ),
      ),
    ],
  );
}

Widget _buildStepRow(String label, bool completed, IconData icon) {
  final color = completed ? const Color(0xFF10B981) : const Color(0xFF9CA3AF);
  return Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      const Spacer(),
      if (completed) const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
    ],
  );
}
