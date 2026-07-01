import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/passenger_card.dart';
import '../../../app_theme.dart';

class PassengersTab extends StatelessWidget {
  final String viajeId;
  final int capacidad;
  final bool enCamino;
  final void Function(Map<String, dynamic> pasajero, int numeroAsiento) onValidar;

  const PassengersTab({
    super.key,
    required this.viajeId,
    required this.capacidad,
    required this.enCamino,
    required this.onValidar,
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
              Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final asientoNum = (data['numeroAsiento'] as num?)?.toInt() ?? 0;
                  
                  // Necesitamos el DNI, que usualmente está en la colección 'usuarios'
                  // Para CP01, mostraremos lo que tenemos en la reserva + fetch DNI if possible
                  return _buildPassengerCard(context, data, asientoNum);
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPassengerCard(BuildContext context, Map<String, dynamic> resData, int asiento) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(resData['pasajeroUid']).get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final dni = userData['dni'] ?? '-'; // CP01: Incluir DNI

        // Reutilizamos el estilo del passengerCard widget pero con datos extendidos
        return passengerCard(
          viajeId: viajeId,
          pasajero: {
            'nombre': resData['nombreViajero'] ?? 'Pasajero',
            'asiento': asiento,
            'paradero': resData['paradero'] ?? '-', // CP01: Punto de recojo
            'dni': dni, // CP01: DNI
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
