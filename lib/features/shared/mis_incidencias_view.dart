import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/incidencia_service.dart';

class MisIncidenciasView extends StatefulWidget {
  const MisIncidenciasView({super.key});

  @override
  State<MisIncidenciasView> createState() => _MisIncidenciasViewState();
}

class _MisIncidenciasViewState extends State<MisIncidenciasView> {
  final _incidenciaService = IncidenciaService();

  static const Map<String, Color> _coloresEstado = {
    'pendiente': Color(0xFFF59E0B),
    'revisado': Color(0xFF1E6BFF),
    'resuelto': Color(0xFF10B981),
  };

  static const Map<String, String> _etiquetasEstado = {
    'pendiente': 'Pendiente',
    'revisado': 'En revisión',
    'resuelto': 'Resuelto',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Mis incidencias',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _incidenciaService.getMisIncidencias(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E6BFF)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar incidencias: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)),
            );
          }

          final incidencias = snapshot.data ?? [];

          if (incidencias.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.report_problem_outlined,
                        color: Color(0xFF6B7280), size: 40),
                    SizedBox(height: 10),
                    Text(
                      'No has reportado ninguna incidencia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: incidencias.length,
            itemBuilder: (context, i) => _incidenciaCard(incidencias[i]),
          );
        },
      ),
    );
  }

  Widget _incidenciaCard(Map<String, dynamic> inc) {
    final tipo = inc['tipo'] ?? '-';
    final descripcion = inc['descripcion'] ?? '';
    final estado = inc['estado'] ?? 'pendiente';
    final creadoEn = inc['creadoEn'];
    final fechaTexto =
    creadoEn is Timestamp ? _fmt(creadoEn.toDate()) : 'Procesando...';
    final color = _coloresEstado[estado] ?? const Color(0xFF6B7280);
    final etiqueta = _etiquetasEstado[estado] ?? estado;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(tipo,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(etiqueta,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(descripcion,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 13)),
          const SizedBox(height: 10),
          Text(fechaTexto,
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 11)),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}