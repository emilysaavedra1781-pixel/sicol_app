import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_theme.dart';

class ReservasHistorialView extends StatelessWidget {
  final String uid;
  const ReservasHistorialView({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('HISTORIAL DE VIAJES', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservas')
            .where('pasajeroUid', isEqualTo: uid)
            .where('estado', isEqualTo: 'calificada')
            .orderBy('creadoEn', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: CabifyColors.error, size: 48),
                    const SizedBox(height: 16),
                    const Text('Error al cargar historial.', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString().contains('failed-precondition')
                      ? 'Se requiere un índice compuesto en Firestore.'
                      : 'Verifica tu conexión.',
                      textAlign: TextAlign.center, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No tienes viajes en tu historial', style: TextStyle(color: CabifyColors.textSecondary)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final fecha = (data['creadoEn'] as Timestamp?)?.toDate();
              
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history)),
                  title: Text(data['paradero'] ?? 'Viaje Terminado', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(fecha != null ? '${fecha.day}/${fecha.month}/${fecha.year}' : '-'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text('Calificado', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
