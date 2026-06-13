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
  // Paso 1: colectivo debe estar lleno
  // Paso 2: todos los pasajeros deben haber confirmado su código
  final bool puedeArrancar = estaLleno && todosAbordaron;

  Widget banner;

  if (!estaLleno) {
    // Paso 1 no cumplido: faltan reservas
    final faltanAsientos = capacidad - asientosOcupados;
    banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(children: [
        const Icon(Icons.hourglass_empty_rounded,
            color: Color(0xFF6B7280), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Faltan $faltanAsientos asiento(s) por reservar para poder arrancar.',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ),
      ]),
    );
  } else if (pendientes > 0) {
    // Paso 1 cumplido, paso 2 pendiente: faltan confirmaciones
    banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.pending_rounded,
            color: Color(0xFFF59E0B), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Faltan $pendientes pasajero(s) por confirmar su código de reserva.',
            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: onVerificar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Verificar',
                style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  } else {
    // Ambos pasos cumplidos
    banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.check_circle_rounded,
            color: Color(0xFF10B981), size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '¡Colectivo lleno y todos confirmaron! Puedes arrancar.',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 13),
          ),
        ),
      ]),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Indicador de pasos
      Row(children: [
        _paso(
          numero: '1',
          label: 'Colectivo lleno',
          completado: estaLleno,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: estaLleno
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(width: 8),
        _paso(
          numero: '2',
          label: 'Códigos confirmados',
          completado: estaLleno && todosAbordaron,
          bloqueado: !estaLleno,
        ),
      ]),
      const SizedBox(height: 12),
      banner,
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: (arrancando || !puedeArrancar) ? null : onArrancar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            disabledBackgroundColor: const Color(0xFF374151),
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0xFF6B7280),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: arrancando
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : Icon(
              puedeArrancar
                  ? Icons.play_arrow_rounded
                  : Icons.lock_outline_rounded,
              size: 26),
          label: Text(
            arrancando
                ? 'Arrancando...'
                : puedeArrancar
                ? 'Arrancar viaje'
                : !estaLleno
                ? 'Esperando que se llene el colectivo'
                : 'Esperando confirmación de pasajeros',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );
}

Widget _paso({
  required String numero,
  required String label,
  required bool completado,
  bool bloqueado = false,
}) {
  final color = completado
      ? const Color(0xFF10B981)
      : bloqueado
      ? const Color(0xFF374151)
      : const Color(0xFFF59E0B);

  return Column(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Center(
          child: completado
              ? Icon(Icons.check_rounded, color: color, size: 14)
              : Text(numero,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    ],
  );
}