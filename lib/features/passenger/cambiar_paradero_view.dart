import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app_theme.dart';

class CambiarParaderoView extends StatefulWidget {
  final String reservaId;
  final String viajeId;
  final String currentParadero;
  final String ruta;
  final int numeroAsiento;

  const CambiarParaderoView({
    super.key,
    required this.reservaId,
    required this.viajeId,
    required this.currentParadero,
    required this.ruta,
    required this.numeroAsiento,
  });

  @override
  State<CambiarParaderoView> createState() => _CambiarParaderoViewState();
}

class _CambiarParaderoViewState extends State<CambiarParaderoView> {
  final _searchCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  String _filter = "";
  bool _updating = false;

  // Mapa de conversión de ruta interna a rutaId de Firestore
  String get _rutaIdFirestore {
    if (widget.ruta == 'chosica_lima') return 'Chosica a Lima';
    if (widget.ruta == 'lima_chosica') return 'Lima a Chosica';
    return widget.ruta;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateParadero(String newParadero) async {
    if (_updating) return;
    setState(() => _updating = true);

    try {
      await _db.runTransaction((transaction) async {
        final resRef = _db.collection('reservas').doc(widget.reservaId);
        final viajeRef = _db.collection('viajes').doc(widget.viajeId);

        // 1. Actualizar reserva
        transaction.update(resRef, {'paradero': newParadero});

        // 2. Actualizar en el objeto de viaje (asientos)
        final vSnap = await transaction.get(viajeRef);
        if (vSnap.exists) {
          final data = vSnap.data() as Map<String, dynamic>;
          final asientos = Map<String, dynamic>.from(data['asientos'] ?? {});
          final key = 'asiento_${widget.numeroAsiento}';
          
          if (asientos.containsKey(key)) {
            final asientoData = Map<String, dynamic>.from(asientos[key]);
            if (asientoData['pasajero'] != null) {
              final pasData = Map<String, dynamic>.from(asientoData['pasajero']);
              pasData['paradero'] = newParadero;
              asientoData['pasajero'] = pasData;
              asientos[key] = asientoData;
              
              transaction.update(viajeRef, {
                'asientos': asientos,
                'cambioParaderoReciente': true, // Flag para notificar al conductor visualmente
                'lastUpdate': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Punto de recojo actualizado'), backgroundColor: CabifyColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

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
        title: const Text('Cambiar Punto de Recojo', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar paradero...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _filter = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('paraderos')
                  .where('rutaId', isEqualTo: _rutaIdFirestore)
                  .where('activo', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final allDocs = snapshot.data!.docs;
                final filtered = allDocs.where((doc) {
                  final name = (doc['nombre'] as String).toLowerCase();
                  return name.contains(_filter);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No se encontraron paraderos'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final name = filtered[i]['nombre'] as String;
                    final ref = filtered[i]['referencia'] as String;
                    final isCurrent = name == widget.currentParadero;

                    return ListTile(
                      title: Text(name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(ref),
                      trailing: isCurrent 
                        ? const Icon(Icons.check_circle, color: CabifyColors.primary)
                        : const Icon(Icons.chevron_right),
                      onTap: isCurrent || _updating ? null : () => _updateParadero(name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
