import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViajesTab extends StatelessWidget {
  final FirebaseFirestore db;
  const ViajesTab({super.key, required this.db});

  // Forzar salida: habilita al conductor para arrancar aunque no esté lleno
  Future<void> _forzarSalida(BuildContext context, String viajeId, String conductor, int asientosOcupados, int capacidad) async {
    final faltantes = capacidad - asientosOcupados;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Forzar Salida', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El colectivo de $conductor tiene $asientosOcupados/$capacidad asientos ocupados. Faltan $faltantes asiento(s).',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
              'Al forzar la salida, el conductor podrá arrancar el viaje sin necesidad de llenar todos los asientos.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Forzar Salida'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.collection('viajes').doc(viajeId).update({
        'forzadoPorAdmin': true,
        'fechaForzado': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Salida forzada para $conductor. Ya puede arrancar.'),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // Liberar unidad: cierra un viaje ya en curso por retraso
  Future<void> _liberarUnidadRetrasada(BuildContext context, String viajeId, String conductor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Forzar Cierre de Viaje', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Deseas liberar de forma remota el vehículo de $conductor debido a un retraso prolongado o bloqueo operativo?',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
            child: const Text('Liberar Unidad'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.collection('viajes').doc(viajeId).update({
        'estado': 'finalizado',
        'forzadoPorAdmin': true,
        'fechaFinalizacion': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidad liberada en la red distributiva.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('viajes').where('estado', isEqualTo: 'activo').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay operaciones activas en este momento',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final conductor = d['conductorNombre'] ?? 'Conductor';
            final asientosOcupados = (d['asientosOcupados'] as num?)?.toInt() ?? 0;
            final capacidad = (d['capacidad'] as num?)?.toInt() ?? 4;
            final enCamino = d['estado'] == 'en_camino';
            final forzado = d['forzadoPorAdmin'] == true;
            final estaLleno = asientosOcupados >= capacidad;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del viaje
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(conductor,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(
                              'Ruta: ${d['ruta'] == 'esperando' ? 'Disponible en Espera' : (d['rutaLabel'] ?? '-')}',
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$asientosOcupados/$capacidad Asientos',
                            style: const TextStyle(color: Color(0xFF1E6BFF), fontWeight: FontWeight.bold),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: enCamino
                                  ? const Color(0xFF1E6BFF).withOpacity(0.15)
                                  : const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              enCamino ? 'En camino' : 'Esperando',
                              style: TextStyle(
                                color: enCamino ? const Color(0xFF1E6BFF) : const Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Badge si ya fue forzado
                  if (forzado && !enCamino) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.flash_on, color: Color(0xFFF59E0B), size: 14),
                        SizedBox(width: 6),
                        Text('Salida forzada — el conductor puede arrancar',
                            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Botones según estado
                  if (!enCamino && !estaLleno && !forzado)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _forzarSalida(context, docs[i].id, conductor, asientosOcupados, capacidad),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B).withOpacity(0.15),
                          foregroundColor: const Color(0xFFF59E0B),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: const Text('Forzar Salida sin llenar'),
                      ),
                    ),

                  if (enCamino)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _liberarUnidadRetrasada(context, docs[i].id, conductor),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30).withOpacity(0.1),
                          foregroundColor: const Color(0xFFFF3B30),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 16),
                        label: const Text('Liberar unidad por retraso'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}