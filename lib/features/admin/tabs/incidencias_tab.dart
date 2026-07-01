import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../app_theme.dart';

class IncidenciasTab extends StatefulWidget {
  final FirebaseFirestore db;
  const IncidenciasTab({super.key, required this.db});

  @override
  State<IncidenciasTab> createState() => _IncidenciasTabState();
}

class _IncidenciasTabState extends State<IncidenciasTab> {
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _tipoFiltro;
  String? _conductorFiltro;

  final List<String> _tiposIncidencia = [
    'Pasajero no se presentó',
    'Problema con el pago',
    'Comportamiento inapropiado',
    'Conductor no se presentó',
    'Vehículo en mal estado',
    'Retraso',
    'Accidente',
    'Desvío de ruta',
    'Problema con pasajero',
    'Otro',
  ];

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: CabifyColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      if (picked.start.isAfter(picked.end)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rango de fechas inválido'), backgroundColor: CabifyColors.error),
        );
        return;
      }
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(_fechaInicio == null ? 'FECHAS' : '${DateFormat('dd/MM').format(_fechaInicio!)} - ${DateFormat('dd/MM').format(_fechaFin!)}', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ),
              const SizedBox(width: 8),
              if (_fechaInicio != null || _tipoFiltro != null || _conductorFiltro != null)
                IconButton(
                  onPressed: () => setState(() { _fechaInicio = null; _fechaFin = null; _tipoFiltro = null; _conductorFiltro = null; }),
                  icon: const Icon(Icons.filter_list_off, color: CabifyColors.error),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _tipoFiltro,
                  hint: const Text('TIPO', style: TextStyle(fontSize: 11)),
                  items: _tiposIncidencia.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _tipoFiltro = v),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.db.collection('usuarios').where('rol', isEqualTo: 'conductor').snapshots(),
                  builder: (context, snap) {
                    final conductors = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      value: _conductorFiltro,
                      hint: const Text('CONDUCTOR', style: TextStyle(fontSize: 11)),
                      items: conductors.map((c) => DropdownMenuItem(value: c.id, child: Text(c['nombre'], style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => _conductorFiltro = v),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    );
                  }
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    Query query = widget.db.collection('incidencias').orderBy('creadoEn', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('Error de conexión', style: TextStyle(color: CabifyColors.error)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        // Filtrado local para combinación compleja
        if (_fechaInicio != null && _fechaFin != null) {
          docs = docs.where((d) {
            final f = (d['creadoEn'] as Timestamp?)?.toDate();
            return f != null && f.isAfter(_fechaInicio!) && f.isBefore(_fechaFin!);
          }).toList();
        }
        if (_tipoFiltro != null) {
          docs = docs.where((d) => d['tipo'] == _tipoFiltro).toList();
        }
        if (_conductorFiltro != null) {
          docs = docs.where((d) => d['usuarioId'] == _conductorFiltro || d['rolUsuario'] == 'pasajero').toList();
          // Nota: Si es pasajero reportando, filtramos por viajeId vinculado al conductor (lógica simplificada aquí)
        }

        if (docs.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('No se encontraron incidencias con los criterios seleccionados.', textAlign: TextAlign.center, style: TextStyle(color: CabifyColors.textSecondary)),
          ));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final fecha = (data['creadoEn'] as Timestamp?)?.toDate();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _badge(data['estado'] ?? 'PENDIENTE'),
                        Text(fecha != null ? DateFormat('dd/MM/yyyy').format(fecha) : '-', style: const TextStyle(fontSize: 11, color: CabifyColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(data['tipo'] ?? 'Sin tipo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(data['descripcion'] ?? '', style: const TextStyle(fontSize: 13, color: CabifyColors.textSecondary)),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: CabifyColors.primary),
                        const SizedBox(width: 4),
                        Text('Rol: ${data['rolUsuario']?.toUpperCase()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (data['viajeId'] != null) Text('VIAJE: ${data['viajeId'].toString().substring(0, 5)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(String status) {
    Color color = CabifyColors.success;
    if (status == 'PENDIENTE') color = Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
