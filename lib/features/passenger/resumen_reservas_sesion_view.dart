import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app_theme.dart';

class ResumenReservasSesionView extends StatelessWidget {
  final String viajeId;

  const ResumenReservasSesionView({super.key, required this.viajeId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tus Reservas', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservas')
              .where('pasajeroUid', isEqualTo: user?.uid)
              .where('viajeId', isEqualTo: viajeId)
              .where('creadoEn', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('No se encontraron reservas recientes.'));

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¡Reserva(s) Listas!', 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: CabifyColors.primary)),
                  const SizedBox(height: 8),
                  const Text('Muestra estos códigos al conductor al subir al vehículo.',
                    style: TextStyle(color: CabifyColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(data['nombreViajero'] ?? 'Pasajero', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text('Asiento ${data['numeroAsiento']} · DNI ${data['dniViajero'] ?? "-"}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: CabifyColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(data['codigoVerificacion'] ?? '-----',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: CabifyColors.primary, letterSpacing: 2, fontSize: 16)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: const Text('FINALIZAR Y VOLVER AL INICIO'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
