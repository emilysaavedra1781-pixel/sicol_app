import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../app_theme.dart';
import '../../passenger/comprobante_pago_view.dart';

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
      final data = snap.hasData && snap.data!.docs.isNotEmpty
          ? (snap.data!.docs.first.data() as Map<String, dynamic>)
          : null;
      
      final estado = data?['estado'] ?? 'confirmada';
      final abordado = estado == 'abordado';
      final finalizado = estado == 'finalizada' || estado == 'calificada';

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: CircleAvatar(
              backgroundColor: finalizado ? Colors.grey[100] : (abordado ? CabifyColors.success.withValues(alpha: 0.1) : CabifyColors.primary.withValues(alpha: 0.1)),
              child: Icon(
                finalizado ? Icons.check_circle : (abordado ? Icons.how_to_reg : Icons.person),
                color: finalizado ? Colors.grey : (abordado ? CabifyColors.success : CabifyColors.primary),
              ),
            ),
            title: Text(pasajero['nombre'] ?? 'Pasajero', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // CP01: Mostrar DNI y Paradero
                Text('DNI: ${pasajero['dni'] ?? "-"} · Asiento ${pasajero['asiento']}', 
                  style: const TextStyle(fontSize: 11, color: CabifyColors.textSecondary)),
                Text('Recojo: ${pasajero['paradero'] ?? "-"}', 
                  style: const TextStyle(fontSize: 11, color: CabifyColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data != null)
                  IconButton(
                    icon: const Icon(Icons.receipt_long_rounded, color: CabifyColors.textSecondary, size: 20),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComprobantePagoView(reservaId: snap.data!.docs.first.id))),
                  ),
                if (!finalizado && !abordado)
                  IconButton(
                    icon: const Icon(Icons.location_on_rounded, color: CabifyColors.primary, size: 20),
                    onPressed: () => _notificarLlegada(context, pasajero['nombre'] ?? 'Pasajero'),
                  ),
                _buildAction(finalizado, abordado, onValidar),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _notificarLlegada(BuildContext context, String nombrePasajero) async {
  try {
    await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('notificarLlegadaManual').call({
      'nombrePasajero': nombrePasajero,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación de llegada enviada'), backgroundColor: CabifyColors.success)
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error)
      );
    }
  }
}

Widget _buildAction(bool finalizado, bool abordado, VoidCallback onValidar) {
  if (finalizado) {
    return const Text('YA BAJÓ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10));
  }
  if (abordado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: CabifyColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: const Text('ABORDADO', style: TextStyle(color: CabifyColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
  return ElevatedButton(
    onPressed: onValidar,
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(80, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
    child: const Text('VERIFICAR'),
  );
}
