import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'driver_home_view.dart';
import '../../app_theme.dart';

class DriverViajeDetalleView extends StatelessWidget {
  final Map<String, dynamic> viaje;

  const DriverViajeDetalleView({super.key, required this.viaje});

  @override
  Widget build(BuildContext context) {
    final rutaLabel = viaje['rutaLabel'] ?? 'Sin ruta';
    final asientos = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
    final monto = asientos * 10.0;
    
    final iniciadoEn = viaje['iniciadoEn'] as Timestamp?;
    final cerradoEn = viaje['cerradoEn'] as Timestamp?;
    
    String duracion = '-';
    if (iniciadoEn != null && cerradoEn != null) {
      final diff = cerradoEn.toDate().difference(iniciadoEn.toDate());
      duracion = '${diff.inMinutes} min';
    }

    final pasajeros = (viaje['asientos'] as Map<String, dynamic>? ?? {})
        .values
        .where((a) => a['pasajero'] != null)
        .map((a) => a['pasajero'] as Map<String, dynamic>)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CabifyColors.primary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DriverHomeView()),
              );
            }
          },
        ),
        title: const Text('Detalle del Viaje', style: TextStyle(fontSize: 16, color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(rutaLabel),
            const SizedBox(height: 24),
            _buildInfoCard(iniciadoEn, cerradoEn, duracion, asientos, monto),
            const SizedBox(height: 32),
            const Text('PASAJEROS ATENDIDOS', 
              style: TextStyle(color: CabifyColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            pasajeros.isEmpty 
              ? const Text('No se registraron pasajeros.', style: TextStyle(color: CabifyColors.textSecondary))
              : Column(children: pasajeros.map((p) => _pasajeroItem(p)).toList()),
            const SizedBox(height: 32),
            _buildIncidenciasSection(viaje['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String ruta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ruta, style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Resumen del recorrido finalizado', style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildInfoCard(Timestamp? inicio, Timestamp? fin, String duracion, int pax, double monto) {
    final df = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CabifyColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dataItem('INICIO', inicio != null ? df.format(inicio.toDate()) : '--:--'),
              _dataItem('FIN', fin != null ? df.format(fin.toDate()) : '--:--'),
              _dataItem('DURACIÓN', duracion),
            ],
          ),
          const Divider(height: 40, color: CabifyColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dataItem('PASAJEROS', '$pax'),
              _dataItem('RECAUDADO', 'S/ ${monto.toStringAsFixed(2)}', color: CabifyColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataItem(String label, String value, {Color color = CabifyColors.textPrimary}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _pasajeroItem(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CabifyColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 14, backgroundColor: Color(0xFFF3F4F6), child: Icon(Icons.person, size: 14, color: CabifyColors.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['nombre'] ?? 'Pasajero', style: const TextStyle(color: CabifyColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Asiento ${p['asiento']} · ${p['paradero'] ?? '-'}', style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidenciasSection(String? viajeId) {
    if (viajeId == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('incidencias').where('viajeId', isEqualTo: viajeId).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('INCIDENCIAS', style: TextStyle(color: CabifyColors.error, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return Text('• ${data['tipo']}: ${data['descripcion']}', 
                style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12));
            }).toList(),
          ],
        );
      },
    );
  }
}
