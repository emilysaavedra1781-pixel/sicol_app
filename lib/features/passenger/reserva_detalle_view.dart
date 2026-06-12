import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReservaDetalleView extends StatelessWidget {
  final String reservaId;
  final String codigo;
  final String nombrePasajero;

  const ReservaDetalleView({
    super.key,
    required this.reservaId,
    required this.codigo,
    required this.nombrePasajero,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Detalle de reserva'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              // Vuelve al home del pasajero (pop todo el stack hasta root)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Listo',
                style: TextStyle(
                    color: Color(0xFF1E6BFF),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.collection('reservas').doc(reservaId).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child:
                CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }
          if (!snap.data!.exists) {
            return const Center(
                child: Text('Reserva no encontrada.',
                    style: TextStyle(color: Colors.white)));
          }

          final res = snap.data!.data() as Map<String, dynamic>;
          final asiento = res['numeroAsiento'] ?? '-';
          final paradero = res['paradero'] ?? '-';
          final rutaLabel = res['ruta'] == 'chosica_lima'
              ? 'Chosica → Lima'
              : res['ruta'] == 'lima_chosica'
              ? 'Lima → Chosica'
              : res['ruta'] ?? '-';
          final monto = (res['monto'] as num?)?.toInt() ?? 15;
          final codigoFinal = res['codigoVerificacion'] ?? codigo;
          final nombreFinal = res['nombreViajero'] ?? nombrePasajero;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Icono de éxito ───────────────────────────────────────
                const SizedBox(height: 10),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        width: 2),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFF10B981), size: 36),
                ),
                const SizedBox(height: 14),
                const Text('¡Reserva confirmada!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Para: $nombreFinal',
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 24),

                // ── Código OTP ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF1E6BFF).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('CÓDIGO DE VERIFICACIÓN',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 10),
                      Text(codigoFinal,
                          style: const TextStyle(
                              color: Color(0xFF1E6BFF),
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8)),
                      const SizedBox(height: 8),
                      const Text('Muéstralo al conductor al abordar',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Info de la reserva ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                    border:
                    Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resumen',
                          style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 16),
                      _filaDetalle(Icons.person_outline, 'Pasajero',
                          nombreFinal),
                      const SizedBox(height: 12),
                      _filaDetalle(Icons.event_seat_rounded, 'Asiento',
                          'Asiento $asiento'),
                      const SizedBox(height: 12),
                      _filaDetalle(Icons.location_on_outlined,
                          'Paradero de recojo', paradero),
                      const SizedBox(height: 12),
                      _filaDetalle(
                          Icons.route_outlined, 'Ruta', rutaLabel),
                      const SizedBox(height: 12),
                      _filaDetalle(
                        Icons.attach_money_rounded,
                        'Monto',
                        'S/ $monto.00',
                        valueColor: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 12),
                      _filaDetalle(
                        Icons.check_circle_outline,
                        'Estado',
                        'Confirmada',
                        valueColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Botón ir a mis reservas ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(
                        Icons.confirmation_number_rounded,
                        size: 18),
                    label: const Text('Ver mis reservas',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filaDetalle(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 15),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}