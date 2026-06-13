import 'package:flutter/material.dart';
import '../widgets/passenger_card.dart';
import '../widgets/admin_alert.dart';

class PassengersTab extends StatelessWidget {
  final String viajeId;
  final List<Map<String, dynamic>> pasajeros;
  final int capacidad;
  final bool enCamino;
  final void Function(Map<String, dynamic> pasajero, int numeroAsiento)
  onValidar;

  const PassengersTab({
    super.key,
    required this.viajeId,
    required this.pasajeros,
    required this.capacidad,
    required this.enCamino,
    required this.onValidar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pasajeros',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color:
                      const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${pasajeros.length}/$capacidad',
                      style: const TextStyle(
                          color: Color(0xFF1E6BFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
          if (pasajeros.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: enCamino
                    ? const Color(0xFF1E6BFF).withValues(alpha: 0.08)
                    : const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enCamino
                      ? const Color(0xFF1E6BFF).withValues(alpha: 0.25)
                      : const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: enCamino
                        ? const Color(0xFF1E6BFF)
                        : const Color(0xFF10B981),
                    size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                      enCamino
                          ? 'Toca "Verificar" en cada pasajero para validar su código al abordar.'
                          : 'Valida el código de cada pasajero antes de arrancar el viaje.',
                      style: TextStyle(
                          color: enCamino
                              ? const Color(0xFF1E6BFF)
                              : const Color(0xFF10B981),
                          fontSize: 12),
                    )),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          pasajeros.isEmpty
              ? sinPasajeros()
              : Column(
              children: pasajeros.map((p) {
                final asientoNum = p['asiento'];
                final numero = asientoNum is int
                    ? asientoNum
                    : int.tryParse(asientoNum?.toString() ?? '0') ?? 0;
                return passengerCard(
                  viajeId: viajeId,
                  pasajero: p,
                  enCamino: enCamino,
                  onValidar: () => onValidar(p, numero),
                );
              }).toList()),
        ],
      ),
    );
  }
}