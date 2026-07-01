import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/incidencia_service.dart';
import '../../app_theme.dart';

class MisIncidenciasView extends StatefulWidget {
  const MisIncidenciasView({super.key});

  @override
  State<MisIncidenciasView> createState() => _MisIncidenciasViewState();
}

class _MisIncidenciasViewState extends State<MisIncidenciasView> {
  final _incidenciaService = IncidenciaService();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
        title: const Text('Mis Incidencias', style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _incidenciaService.getMisIncidencias(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: CabifyColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Error de conexión con el historial.', 
                      textAlign: TextAlign.center, style: TextStyle(color: CabifyColors.error)),
                  ],
                ),
              ),
            );
          }

          final incidencias = snapshot.data ?? [];
          
          // CP09: Doble verificación de seguridad en la UI
          final misFiltradas = incidencias.where((inc) => inc['usuarioId'] == _currentUid).toList();

          if (misFiltradas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.report_problem_outlined, color: Colors.grey[300], size: 64),
                  const SizedBox(height: 16),
                  const Text('No tienes incidencias registradas en tus viajes.', // CP07
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: misFiltradas.length,
            itemBuilder: (context, i) => _incidenciaCard(misFiltradas[i]),
          );
        },
      ),
    );
  }

  Widget _incidenciaCard(Map<String, dynamic> inc) {
    final estado = inc['estado'] ?? 'pendiente';
    final fecha = (inc['creadoEn'] as Timestamp?)?.toDate();
    Color color = Colors.amber;
    if (estado == 'resuelto') color = CabifyColors.success;
    if (estado == 'revisado') color = CabifyColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(estado.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-', // CP03
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Text(inc['tipo'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(inc['descripcion'] ?? '', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
