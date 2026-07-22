import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/passenger_card.dart';
import '../../../app_theme.dart';

class PassengersTab extends StatelessWidget {
  final String viajeId;
  final int capacidad;
  final bool enCamino;
  final void Function(Map<String, dynamic> pasajero, int numeroAsiento) onValidar;
  final void Function(String codigoEncuentro) onValidarGrupo;

  const PassengersTab({
    super.key,
    required this.viajeId,
    required this.capacidad,
    required this.enCamino,
    required this.onValidar,
    required this.onValidarGrupo,
  });

  @override
  Widget build(BuildContext context) {
    if (viajeId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Necesitas un viaje activo para ver la lista de pasajeros.', // CP06
            textAlign: TextAlign.center,
            style: TextStyle(color: CabifyColors.textSecondary),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      // CP05: Solo pasajeros con pago confirmado ('confirmada' o 'abordado')
      stream: FirebaseFirestore.instance
          .collection('reservas')
          .where('viajeId', isEqualTo: viajeId)
          .where('estado', whereIn: ['confirmada', 'abordado'])
          .snapshots(), // CP03 & CP04: Actualización en tiempo real
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: CabifyColors.error)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // CP02: Lista vacía
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded, color: Colors.grey[300], size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Aún no hay pasajeros con reserva confirmada para este viaje.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CabifyColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        // Agrupar por reservaGroupId
        final Map<String, List<DocumentSnapshot>> grupos = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final groupId = data['reservaGroupId'] ?? doc.id; // Fallback si no tiene groupId
          if (!grupos.containsKey(groupId)) grupos[groupId] = [];
          grupos[groupId]!.add(doc);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lista de Pasajeros', style: Theme.of(context).textTheme.titleLarge),
                  _buildCountBadge(docs.length),
                ],
              ),
              const SizedBox(height: 24),
              ...grupos.entries.map((entry) {
                final grupoDocs = entry.value;
                final bool esGrupo = grupoDocs.length > 1;
                final firstData = grupoDocs.first.data() as Map<String, dynamic>;
                final String ce = firstData['codigoEncuentro'] ?? '---';
                
                // Verificar si hay alguien pendiente en el grupo
                final bool hayPendientes = grupoDocs.any((d) => (d.data() as Map)['estado'] == 'confirmada');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (esGrupo)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.group_rounded, color: CabifyColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Text('Grupo de ${grupoDocs.length} personas', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CabifyColors.primary)),
                              ],
                            ),
                            if (hayPendientes)
                              TextButton.icon(
                                onPressed: () => onValidarGrupo(ce),
                                icon: const Icon(Icons.verified_user_rounded, size: 16),
                                label: const Text('VALIDAR GRUPO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ...grupoDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final asientoNum = (data['numeroAsiento'] as num?)?.toInt() ?? 0;
                      return Padding(
                        padding: EdgeInsets.only(left: esGrupo ? 12 : 0),
                        child: _buildPassengerCard(context, data, asientoNum),
                      );
                    }),
                    if (esGrupo) const SizedBox(height: 16),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassengerCard(BuildContext context, Map<String, dynamic> resData, int asiento) {
    final bool esTitular = resData['esTitular'] ?? false;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(resData['pasajeroUid']).get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final dni = resData['dniViajero'] ?? userData['dni'] ?? '-'; // CP01: Priorizar DNI de la reserva

        return passengerCard(
          viajeId: viajeId,
          pasajero: {
            'nombre': '${resData['nombreViajero'] ?? 'Pasajero'}${esTitular ? " (Titular)" : ""}',
            'asiento': asiento,
            'paradero': resData['paradero'] ?? '-', 
            'dni': dni,
          },
          enCamino: enCamino,
          onValidar: () => onValidar(resData, asiento),
        );
      },
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CabifyColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count/$capacidad',
          style: const TextStyle(color: CabifyColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
