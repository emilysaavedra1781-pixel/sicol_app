import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app_theme.dart';

class IngresosAdminTab extends StatelessWidget {
  final FirebaseFirestore db;
  const IngresosAdminTab({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('viajes').where('estado', isEqualTo: 'finalizado').orderBy('iniciadoEn', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        double totalRecaudado = 0;
        double totalComisiones = 0;

        for (var d in docs) {
          final ingreso = (d['ingresoTotal'] as num?)?.toDouble() ?? 0;
          totalRecaudado += ingreso;
          totalComisiones += ingreso * 0.10; // 10% del sistema
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: CabifyColors.border)),
              ),
              child: Column(
                children: [
                  const Text('BALANCE GENERAL', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statSummary('TOTAL PASAJES', 'S/ ${totalRecaudado.toStringAsFixed(2)}'),
                      Container(width: 1, height: 40, color: CabifyColors.border),
                      _statSummary('COMISIONES (10%)', 'S/ ${totalComisiones.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final ingreso = (d['ingresoTotal'] as num?)?.toDouble() ?? 0;
                  final comision = ingreso * 0.10;

                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: CabifyColors.border)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(d['conductorNombre'] ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.bold, color: CabifyColors.textPrimary)),
                      subtitle: Text('Ruta: ${d['rutaLabel'] ?? '-'}', style: const TextStyle(color: CabifyColors.textSecondary)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('S/ ${ingreso.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: CabifyColors.textPrimary)),
                          Text('Fee: S/ ${comision.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: CabifyColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statSummary(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: CabifyColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
