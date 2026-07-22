import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../services/booking_service.dart';
import '../../../app_theme.dart';

class ViajesTab extends StatelessWidget {
  final FirebaseFirestore db;
  final BookingService? bookingService;
  const ViajesTab({super.key, required this.db, this.bookingService});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAvailableDriversSection(context),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('viajes').orderBy('iniciadoEn', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No hay registros de viajes', style: TextStyle(color: CabifyColors.textSecondary)));

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final id = docs[i].id;
                  final enCamino = data['estado'] == 'en_camino';
                  final activo = data['estado'] == 'activo';
                  final finalizado = data['estado'] == 'finalizado';

                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: CabifyColors.border),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: finalizado ? Colors.grey[200] : CabifyColors.primary.withValues(alpha: 0.1),
                        backgroundImage: data['conductorFotoUrl'] != null ? NetworkImage(data['conductorFotoUrl']) : null,
                        child: data['conductorFotoUrl'] == null 
                            ? Icon(Icons.directions_car, color: finalizado ? Colors.grey : CabifyColors.primary)
                            : null,
                      ),
                      title: Text(data['conductorNombre'] ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.bold, color: CabifyColors.textPrimary)),
                      subtitle: Text('${data['rutaLabel'] ?? 'Sin asignar'} · ${data['asientosOcupados']} PAX', style: const TextStyle(color: CabifyColors.textSecondary)),
                      trailing: _buildBadge(data['estado']?.toString().toUpperCase() ?? 'DESCONOCIDO'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoItem('Vehículo', '${data['vehiculo']?['marca']} ${data['vehiculo']?['modelo']}'),
                              _infoItem('Placa', data['vehiculo']?['placa'] ?? '-'),
                              _infoItem('Ingresos', 'S/ ${data['ingresoTotal'] ?? 0}'),
                              if (data['iniciadoPorAdmin'] == true)
                                _infoItem('Iniciado por', 'ADMINISTRADOR', color: CabifyColors.primary),
                              const SizedBox(height: 16),
                              const Text('PASAJEROS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: CabifyColors.textSecondary)),
                              const SizedBox(height: 8),
                              ..._buildPassengersList(context, id, data['asientos'] ?? {}),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  if (activo)
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _forzarArranque(context, id, data['conductorNombre']),
                                        style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.primary, foregroundColor: Colors.white),
                                        child: const Text('FORZAR ARRANQUE'),
                                      ),
                                    ),
                                  if (activo) const SizedBox(width: 8),
                                  if (!finalizado)
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _forzarFinalizacion(context, id),
                                        style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error, foregroundColor: Colors.white),
                                        child: const Text('FINALIZAR VIAJE'),
                                      ),
                                    ),
                                  if (activo || enCamino) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _confirmarCancelacionAdmin(context, id),
                                        style: OutlinedButton.styleFrom(foregroundColor: CabifyColors.error, side: const BorderSide(color: CabifyColors.error)),
                                        child: const Text('CANCELAR (ADMIN)'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableDriversSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('usuarios')
          .where('rol', isEqualTo: 'conductor')
          .where('estado', isEqualTo: 'activo')
          .where('disponible', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: CabifyColors.primary.withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CONDUCTORES DISPONIBLES (SIN VIAJE)', 
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: CabifyColors.primary, letterSpacing: 1)),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return _driverMiniCard(context, d, docs[i].id);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _driverMiniCard(BuildContext context, Map<String, dynamic> data, String uid) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CabifyColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
                backgroundImage: data['fotoUrl'] != null ? NetworkImage(data['fotoUrl']) : null,
                child: data['fotoUrl'] == null ? const Icon(Icons.person, size: 14, color: CabifyColors.primary) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(data['nombre'] ?? '-', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, overflow: TextOverflow.ellipsis)),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => _confirmarForzarInicio(context, uid, data),
            style: ElevatedButton.styleFrom(
              backgroundColor: CabifyColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 32),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            child: const Text('FORZAR INICIO'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarForzarInicio(BuildContext context, String uid, Map<String, dynamic> userData) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forzar Inicio de Viaje'),
        content: Text('¿Confirmas iniciar un viaje remoto para ${userData['nombre']}? Aparecerá como "En Camino" inmediatamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SÍ, INICIAR')),
        ],
      ),
    );

    if (confirm == true) {
      await _ejecutarForzarInicio(uid, userData);
    }
  }

  Future<void> _ejecutarForzarInicio(String conductorUid, Map<String, dynamic> userData) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    final vehiculo = userData['vehiculo'] as Map<String, dynamic>? ?? {};
    final capacidad = int.tryParse(vehiculo['capacidad']?.toString() ?? '4') ?? 4;

    final asientos = <String, dynamic>{};
    for (int i = 1; i <= capacidad; i++) {
      asientos['asiento_$i'] = {'numero': i, 'estado': 'libre', 'pasajero': null};
    }

    // El admin crea el viaje directamente en estado 'en_camino'
    final docRef = await db.collection('viajes').add({
      'conductorUid': conductorUid,
      'conductorNombre': '${userData['nombre']} ${userData['apellido']}',
      'conductorFotoUrl': userData['fotoUrl'],
      'vehiculo': vehiculo,
      'ruta': 'chosica_lima', // Ruta por defecto para inicio forzado
      'rutaLabel': 'Chosica → Lima',
      'estado': 'en_camino',
      'asientos': asientos,
      'capacidad': capacidad,
      'asientosOcupados': 0,
      'ingresoTotal': 0,
      'ubicacionActual': {
        'lat': -11.9347, 
        'lng': -76.6952,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'forzadoPorAdmin': true,
      'iniciadoPorAdmin': true,
      'adminId': adminUid,
      'iniciadoEn': FieldValue.serverTimestamp(),
      'arranqueEn': FieldValue.serverTimestamp(),
    });

    // Marcar conductor como no disponible
    await db.collection('usuarios').doc(conductorUid).update({
      'disponible': false,
      'viajeActivoId': docRef.id,
    });
  }

  Future<void> _forzarArranque(BuildContext context, String viajeId, String? conductor) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forzar Arranque'),
        content: Text('¿Deseas obligar a $conductor a iniciar el recorrido ahora mismo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ARRANCAR')),
        ],
      ),
    );

    if (confirm == true) {
      await db.collection('viajes').doc(viajeId).update({
        'estado': 'en_camino',
        'forzadoPorAdmin': true,
        'arranqueEn': FieldValue.serverTimestamp(),
      });
    }
  }

  List<Widget> _buildPassengersList(BuildContext context, String viajeId, Map<String, dynamic> asientos) {
    List<Widget> list = [];
    asientos.forEach((key, val) {
      if (val['pasajero'] != null) {
        final pasajero = val['pasajero'];
        list.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text('• Asiento ${val['numero']}: ${pasajero['nombre']} (${pasajero['paradero']})',
                  style: const TextStyle(fontSize: 12, color: CabifyColors.textPrimary)),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.cancel_outlined, size: 18, color: CabifyColors.error),
                onPressed: () => _confirmarCancelacionIndividual(context, viajeId, val['numero'], pasajero['nombre']),
                tooltip: 'Cancelar esta reserva',
              ),
            ],
          ),
        ));
      }
    });
    if (list.isEmpty) list.add(const Text('No hay pasajeros registrados', style: TextStyle(fontSize: 12, color: CabifyColors.textSecondary)));
    return list;
  }

  Future<void> _confirmarCancelacionIndividual(BuildContext context, String viajeId, int numAsiento, String nombre) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: Text('¿Deseas cancelar la reserva del asiento $numAsiento ($nombre)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('VOLVER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error),
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Buscar la reserva activa para este asiento
        final snap = await db.collection('reservas')
            .where('viajeId', isEqualTo: viajeId)
            .where('numeroAsiento', isEqualTo: numAsiento)
            .where('estado', whereIn: ['confirmada', 'abordado'])
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          throw Exception('No se encontró una reserva activa para este asiento.');
        }

        final reservaId = snap.docs.first.id;
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

        await bookingService?.forzarCancelacionAdmin(
          reservaId: reservaId,
          viajeId: viajeId,
          numeroAsiento: numAsiento,
          adminUid: adminUid,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reserva cancelada correctamente.'), backgroundColor: CabifyColors.success)
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
  }

  Widget _buildBadge(String status) {
    Color color = Colors.grey;
    if (status == 'ACTIVO') color = CabifyColors.success;
    if (status == 'EN_CAMINO') color = CabifyColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color ?? CabifyColors.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _forzarFinalizacion(BuildContext context, String viajeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Cierre', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de finalizar este viaje de forma remota?', style: TextStyle(color: CabifyColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: CabifyColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error, foregroundColor: Colors.white),
            child: const Text('SÍ, FINALIZAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.collection('viajes').doc(viajeId).update({'estado': 'finalizado', 'cerradoPorAdmin': true});
    }
  }

  Future<void> _confirmarCancelacionAdmin(BuildContext context, String viajeId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Viaje'),
        content: const Text('¿Estás seguro de anular este viaje? Se liberarán los asientos y se notificará a todos los pasajeros.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('VOLVER')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: CabifyColors.error),
            child: const Text('SÍ, ANULAR VIAJE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('forzarCancelacionViajeAdmin')
            .call({'viajeId': viajeId, 'motivo': 'Anulado por Administrador desde Panel'});
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viaje anulado y pasajeros notificados.'), backgroundColor: CabifyColors.success)
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
  }
}
