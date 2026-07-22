import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/booking_service.dart';
import 'paraderos_constants.dart';
import 'colectivo_detalle_view.dart';
import 'rutas_paraderos_view.dart';
import '../../app_theme.dart';

class BuscarTab extends StatefulWidget {
  const BuscarTab({super.key});

  @override
  State<BuscarTab> createState() => _BuscarTabState();
}

class _BuscarTabState extends State<BuscarTab> {
  final _db = FirebaseFirestore.instance;
  final _bookingService = BookingService();

  String? _rutaSeleccionada;
  String? _paraderoSeleccionado;
  Position? _currentPosition;
  bool _gpsActive = false;
  bool _loading = false;

  final TextEditingController _searchCtrl = TextEditingController();

  List<String> get _paraderosActuales =>
      _rutaSeleccionada != null ? paraderosPorRuta[_rutaSeleccionada!]! : [];

  @override
  void initState() {
    super.initState();
    _checkGpsStatus();
  }

  Future<void> _checkGpsStatus() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showGpsDialog('Para continuar necesitas activar la ubicación de tu dispositivo.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showGpsDialog('Los permisos de ubicación son necesarios para realizar reservas.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showGpsDialog('Permisos denegados permanentemente. Actívalos en la configuración.');
      return;
    }

    setState(() => _gpsActive = true);
    _captureLocation();
  }

  void _showGpsDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación requerida', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              if (mounted) Navigator.pop(ctx);
              _checkGpsStatus();
            },
            child: const Text('ACTIVAR UBICACIÓN', style: TextStyle(color: CabifyColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _captureLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Error capturando GPS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: CabifyColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: CabifyColors.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.directions_bus_rounded, color: Colors.white, size: 40),
                    SizedBox(height: 16),
                    Text('¿A dónde vas hoy?',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Busca tu ruta y reserva en segundos',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // RF52: Acceso a la Visualización Gráfica de Rutas
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RutasParaderosView()),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('VER RUTAS Y PARADEROS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: CabifyColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _buildSelectorRuta(),
              const SizedBox(height: 32),
              if (_rutaSeleccionada != null) ...[
                _buildListaColectivos(),
                if (_paraderoSeleccionado == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Selecciona un paradero para filtrar por parada específica',
                        style: TextStyle(color: CabifyColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorRuta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecciona tu destino',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            _botonRuta(label: 'Chosica → Lima', valor: 'chosica_lima', icono: Icons.arrow_forward_rounded),
            const SizedBox(width: 12),
            _botonRuta(label: 'Lima → Chosica', valor: 'lima_chosica', icono: Icons.arrow_back_rounded),
          ],
        ),
        if (_rutaSeleccionada != null) ...[
          const SizedBox(height: 32),
          _seccionTitulo('BÚSQUEDA DE PARADERO'),
          const SizedBox(height: 12),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
              return _paraderosActuales.where((p) => p.toLowerCase().contains(textEditingValue.text.toLowerCase()));
            },
            onSelected: (String selection) {
              setState(() => _paraderoSeleccionado = selection);
              _captureLocation();
            },
            fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
              return TextField(
                controller: ctrl,
                focusNode: focus,
                decoration: const InputDecoration(
                  hintText: 'Busca tu paradero...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          _seccionTitulo('PARADEROS FRECUENTES'),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _paraderosActuales.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final p = _paraderosActuales[i];
                final sel = _paraderoSeleccionado == p;
                return FilterChip(
                  label: Text(p, style: TextStyle(fontSize: 12, color: sel ? Colors.white : CabifyColors.textPrimary)),
                  selected: sel,
                  selectedColor: CabifyColors.primary,
                  onSelected: (val) {
                    setState(() => _paraderoSeleccionado = val ? p : null);
                    if (val) _captureLocation();
                  },
                );
              },
            ),
          ),
          if (_paraderoSeleccionado != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Recojo en: $_paraderoSeleccionado',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _seccionTitulo(String texto) => Text(texto, style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1));

  Widget _botonRuta({required String label, required String valor, required IconData icono}) {
    final sel = _rutaSeleccionada == valor;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _rutaSeleccionada = valor;
          _paraderoSeleccionado = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: sel ? CabifyColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? CabifyColors.primary : CabifyColors.border),
            boxShadow: sel ? [
              BoxShadow(
                color: CabifyColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: sel ? Colors.white : CabifyColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: sel ? Colors.white : CabifyColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaColectivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Colectivos disponibles',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('viajes')
              .where('estado', whereIn: ['activo', 'en_camino'])
              .where('ruta', isEqualTo: _rutaSeleccionada)
              .snapshots(),
          builder: (context, snapRuta) {
            if (snapRuta.hasError) {
              return Center(child: Text('Error: ${snapRuta.error}'));
            }
            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('viajes')
                  .where('estado', whereIn: ['activo', 'en_camino'])
                  .where('ruta', isNull: true)
                  .snapshots(),
              builder: (context, snapNulos) {
                if (snapNulos.hasError) {
                  return Center(child: Text('Error: ${snapNulos.error}'));
                }
                if (!snapRuta.hasData || !snapNulos.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mapaViajes = <String, DocumentSnapshot>{};
                for (final doc in snapRuta.data!.docs) {
                  mapaViajes[doc.id] = doc;
                }
                for (final doc in snapNulos.data!.docs) {
                  mapaViajes[doc.id] = doc;
                }
                
                final viajes = mapaViajes.values.toList();
                // Cola de prioridad: ordenar por fecha de inicio
                viajes.sort((a, b) {
                  final tA = (a.data() as Map)['iniciadoEn'] as Timestamp?;
                  final tB = (b.data() as Map)['iniciadoEn'] as Timestamp?;
                  if (tA == null || tB == null) return 0;
                  return tA.compareTo(tB);
                });

                if (viajes.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.directions_bus_outlined, color: Colors.grey[300], size: 56),
                          const SizedBox(height: 16),
                          const Text('No hay colectivos disponibles en este momento. Intenta más tarde.', // CP02
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: viajes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final viaje = doc.data() as Map<String, dynamic>;
                    final capacidad = (viaje['capacidad'] as num?)?.toInt() ?? 4;
                    final asientosOcupados = (viaje['asientosOcupados'] as num?)?.toInt() ?? 0;
                    final libres = capacidad - asientosOcupados;
                    final esPrimero = index == 0;
                    
                    // CP01: Datos del vehículo
                    final marca = viaje['vehiculo']?['marca'] ?? '';
                    final modelo = viaje['vehiculo']?['modelo'] ?? '';
                    final placa = viaje['vehiculo']?['placa'] ?? '';
                    
                    // CP01: Hora de salida
                    final fSalida = viaje['fechaSalida'] as Timestamp?;
                    final horaSalida = fSalida != null 
                        ? '${fSalida.toDate().hour.toString().padLeft(2, '0')}:${fSalida.toDate().minute.toString().padLeft(2, '0')}'
                        : 'Pronto';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!esPrimero)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Text('PRÓXIMO EN SALIR', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
                                  backgroundImage: viaje['conductorFotoUrl'] != null ? NetworkImage(viaje['conductorFotoUrl']) : null,
                                  child: viaje['conductorFotoUrl'] == null ? const Icon(Icons.person, size: 20, color: CabifyColors.primary) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(viaje['conductorNombre'] ?? 'Conductor',
                                          style: const TextStyle(
                                              color: CabifyColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                      _buildCalificacionRow(viaje['conductorUid']),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('SAlIDA', style: TextStyle(fontSize: 10, color: CabifyColors.textSecondary, fontWeight: FontWeight.bold)),
                                    Text(horaSalida, style: const TextStyle(color: CabifyColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('$marca $modelo · $placa', style: const TextStyle(fontSize: 13, color: CabifyColors.textSecondary, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            if (viaje['vehiculo']?['fotoVehiculoUrl'] != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(viaje['vehiculo']['fotoVehiculoUrl'], height: 100, width: double.infinity, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.event_seat_rounded, size: 16, color: CabifyColors.textSecondary),
                                const SizedBox(width: 8),
                                Text('$libres asientos disponibles',
                                    style: TextStyle(
                                        color: libres > 0 ? CabifyColors.success : CabifyColors.error,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: (libres > 0 && esPrimero)
                                  ? () => _seleccionarColectivo(doc.id, viaje)
                                  : null,
                              child: Text(esPrimero ? 'RESERVAR AHORA' : 'EN TURNO DE ESPERA'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _seleccionarColectivo(String viajeId, Map<String, dynamic> viaje) async {
    // CP03: Concurrencia - Verificar disponibilidad real antes de avanzar
    setState(() => _loading = true); // Asumiendo que agregamos un flag de loading si fuera necesario, pero por ahora mantengamos la lógica original simplificada
    
    try {
      final success = await _bookingService.verificarDisponibilidadViaje(viajeId);

      if (!mounted) return;

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ColectivoDetalleView(
              viajeId: viajeId,
              paradero: _paraderoSeleccionado!,
              rutaSeleccionada: _rutaSeleccionada,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este colectivo acaba de llenarse. Por favor elige otro.'), // CP03
            backgroundColor: CabifyColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CabifyColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildCalificacionRow(String? conductorUid) {
    if (conductorUid == null) return const SizedBox();
    return FutureBuilder<DocumentSnapshot>(
      future: _db.collection('usuarios').doc(conductorUid).get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rating = (data['promedioCalificacion'] as num?)?.toDouble() ?? 0.0;
        final total = (data['totalCalificaciones'] as num?)?.toInt() ?? 0;
        
        return Row(
          children: [
            Icon(Icons.star_rounded, color: rating > 0 ? Colors.amber : Colors.grey[300], size: 16),
            const SizedBox(width: 4),
            Text(rating > 0 ? rating.toStringAsFixed(1) : 'Nuevo', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rating > 0 ? CabifyColors.textPrimary : CabifyColors.textSecondary)),
            if (total > 0)
              Text(' ($total)', style: const TextStyle(fontSize: 11, color: CabifyColors.textSecondary)),
          ],
        );
      },
    );
  }
}
