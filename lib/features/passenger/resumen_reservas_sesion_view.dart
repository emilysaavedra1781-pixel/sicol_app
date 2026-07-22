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
        title: const Text('Resumen de Reservas', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: CabifyColors.primary),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
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

            // Agrupar por código de encuentro
            final Map<String, List<DocumentSnapshot>> grupos = {};
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final String ce = data['codigoEncuentro'] ?? 'S/C';
              if (!grupos.containsKey(ce)) {
                grupos[ce] = [];
              }
              grupos[ce]!.add(doc);
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¡Todo listo para tu viaje!', 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: CabifyColors.primary)),
                  const SizedBox(height: 8),
                  const Text('Muestra el Código de Encuentro al conductor para validar a todo tu grupo.',
                    style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: grupos.length,
                      itemBuilder: (context, index) {
                        final String codigoEncuentro = grupos.keys.elementAt(index);
                        final List<DocumentSnapshot> reservas = grupos[codigoEncuentro]!;
                        
                        return _buildGrupoCard(context, codigoEncuentro, reservas);
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

  Widget _buildGrupoCard(BuildContext context, String codigoEncuentro, List<DocumentSnapshot> reservas) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CabifyColors.primary.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        children: [
          // Header del grupo (Código Encuentro)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CabifyColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CÓDIGO ENCUENTRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: CabifyColors.textSecondary, letterSpacing: 1)),
                    SizedBox(height: 2),
                    Text('Válido para el grupo', style: TextStyle(fontSize: 11, color: CabifyColors.textSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: CabifyColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(codigoEncuentro, 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ],
            ),
          ),
          
          // Lista de pasajeros (Códigos Foto / Verificación)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PASAJEROS Y CÓDIGOS INDIVIDUALES', 
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CabifyColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                ...reservas.map((r) {
                  final data = r.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[100],
                          child: Text('${data['numeroAsiento']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CabifyColors.primary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['nombreViajero'] ?? 'Pasajero', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CabifyColors.textPrimary)),
                              Text('DNI: ${data['dniViajero'] ?? "-"}', style: const TextStyle(fontSize: 11, color: CabifyColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(data['codigoVerificacion'] ?? '-----', 
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
