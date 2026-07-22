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
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: finalizado 
                    ? Colors.grey[100] 
                    : (abordado ? CabifyColors.success.withValues(alpha: 0.1) : CabifyColors.primary.withValues(alpha: 0.1)),
                child: Icon(
                  finalizado ? Icons.check_circle : (abordado ? Icons.how_to_reg : Icons.person),
                  color: finalizado ? Colors.grey : (abordado ? CabifyColors.success : CabifyColors.primary),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              
              // Información Central (Nombre, DNI, Paradero)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pasajero['nombre'] ?? 'Pasajero',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CabifyColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DNI: ${pasajero['dni'] ?? "-"} · Asiento ${pasajero['asiento']}',
                      style: const TextStyle(fontSize: 11, color: CabifyColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 10, color: CabifyColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pasajero['paradero'] ?? "-",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: CabifyColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Acciones a la Derecha
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data != null)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      icon: const Icon(Icons.receipt_long_rounded, color: CabifyColors.textSecondary, size: 20),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComprobantePagoView(reservaId: snap.data!.docs.first.id))),
                    ),
                  if (!finalizado && !abordado)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      icon: const Icon(Icons.location_on_rounded, color: CabifyColors.primary, size: 20),
                      onPressed: () => _notificarLlegada(context, pasajero['nombre'] ?? 'Pasajero'),
                    ),
                  const SizedBox(width: 4),
                  _buildAction(finalizado, abordado, onValidar),
                ],
              ),
            ],
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
