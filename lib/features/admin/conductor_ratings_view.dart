import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';

class ConductorRatingsView extends StatefulWidget {
  final String conductorUid;
  final String conductorNombre;

  const ConductorRatingsView({
    super.key,
    required this.conductorUid,
    required this.conductorNombre,
  });

  @override
  State<ConductorRatingsView> createState() => _ConductorRatingsViewState();
}

class _ConductorRatingsViewState extends State<ConductorRatingsView> {
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  final _db = FirebaseFirestore.instance;

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: CabifyColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: CabifyColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (picked.start.isAfter(picked.end)) {
        // CP07: Rango de fechas inválido
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha de inicio no puede ser posterior a la fecha fin'),
            backgroundColor: CabifyColors.error,
          ),
        );
        return;
      }
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calificaciones: ${widget.conductorNombre}'),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: _fechaInicio != null ? CabifyColors.primary : Colors.grey),
            onPressed: _selectDateRange,
          ),
          if (_fechaInicio != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: _clearFilter,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('calificaciones')
            .where('conductorUid', isEqualTo: widget.conductorUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // CP08: Error de conexión
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: CabifyColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Error al cargar datos: ${snapshot.error}', 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(color: CabifyColors.error)),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var allRatings = snapshot.data!.docs;

          // Ordenar localmente por fecha descendente para evitar dependencia de índices compuestos
          allRatings.sort((a, b) {
            final fa = (a.data() as Map<String, dynamic>)['fechaCreacion'] as Timestamp?;
            final fb = (b.data() as Map<String, dynamic>)['fechaCreacion'] as Timestamp?;
            if (fa == null || fb == null) return 0;
            return fb.compareTo(fa);
          });

          // Aplicar filtro de fecha localmente si es necesario
          if (_fechaInicio != null && _fechaFin != null) {
            allRatings = allRatings.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['fechaCreacion'] as Timestamp?;
              if (timestamp == null) return false;
              final date = timestamp.toDate();
              return date.isAfter(_fechaInicio!) && date.isBefore(_fechaFin!);
            }).toList();
          }

          if (allRatings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border, color: Colors.grey[300], size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _fechaInicio != null 
                        ? 'No hay calificaciones en el rango de fechas seleccionado.' // CP06
                        : 'Este conductor aún no tiene calificaciones registradas.', // CP05
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CabifyColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          // CP02: Calcular promedio filtrado
          double sum = 0;
          for (var doc in allRatings) {
            sum += (doc['puntuacion'] as num).toDouble();
          }
          final average = sum / allRatings.length;

          return Column(
            children: [
              // Resumen de promedio
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: CabifyColors.border)),
                ),
                child: Column(
                  children: [
                    Text(average.toStringAsFixed(1), 
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: CabifyColors.textPrimary)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return Icon(
                          i < average.floor() ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 28,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text('Basado en ${allRatings.length} calificaciones', 
                      style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 12)),
                    if (_fechaInicio != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Filtro: ${DateFormat('dd/MM/yyyy').format(_fechaInicio!)} - ${DateFormat('dd/MM/yyyy').format(_fechaFin!)}',
                          style: const TextStyle(color: CabifyColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              // CP01: Lista de calificaciones
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allRatings.length,
                  itemBuilder: (ctx, i) {
                    final data = allRatings[i].data() as Map<String, dynamic>;
                    final puntuacion = (data['puntuacion'] as num).toInt();
                    final comentario = data['comentario'] as String? ?? '-';
                    final fecha = (data['fechaCreacion'] as Timestamp?)?.toDate();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: List.generate(5, (idx) {
                                    return Icon(
                                      idx < puntuacion ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                                if (fecha != null)
                                  Text(DateFormat('dd/MM/yyyy').format(fecha), // CP03: Fecha formateada
                                    style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(comentario, // CP03: Comentario
                              style: const TextStyle(fontSize: 14, color: CabifyColors.textPrimary)),
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
      ),
    );
  }
}
