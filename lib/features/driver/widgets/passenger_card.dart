import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Widget passengerCard({
  required String viajeId,
  required Map<String, dynamic> pasajero,
  required bool enCamino,
  required VoidCallback onValidar,
}) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('reservas')
        .where('viajeId', isEqualTo: viajeId)
        .where('numeroAsiento', isEqualTo: pasajero['asiento'])
        .limit(1)
        .snapshots(),
    builder: (context, snap) {
      final reservaData = snap.hasData && snap.data!.docs.isNotEmpty
          ? (snap.data!.docs.first.data() as Map<String, dynamic>)
          : null;
      final estadoReserva = reservaData?['estado'] ?? 'confirmada';
      final abordado = estadoReserva == 'abordado';
      final codigo = reservaData?['codigoVerificacion'] ?? '-----';

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: abordado
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : const Color(0xFF1F2937)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: (abordado
                          ? const Color(0xFF10B981)
                          : const Color(0xFF1E6BFF))
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Icon(
                      abordado
                          ? Icons.how_to_reg_rounded
                          : Icons.person,
                      color: abordado
                          ? const Color(0xFF10B981)
                          : const Color(0xFF1E6BFF),
                      size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pasajero['nombre'] ?? '-',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            'Asiento ${pasajero['asiento']} · ${pasajero['paradero'] ?? '-'}',
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
                      ])),
              abordado
                  ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Abordado',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)))
                  : ElevatedButton(
                onPressed: onValidar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Verificar',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            if (!abordado) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Row(children: [
                  const Icon(Icons.vpn_key_rounded,
                      color: Color(0xFF6B7280), size: 14),
                  const SizedBox(width: 8),
                  const Text('Código: ',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                  Text(codigo,
                      style: const TextStyle(
                          color: Color(0xFF1E6BFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4)),
                ]),
              ),
            ],
          ],
        ),
      );
    },
  );
}