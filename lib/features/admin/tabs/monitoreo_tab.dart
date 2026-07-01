import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../app_theme.dart';

class MonitoreoTab extends StatefulWidget {
  final FirebaseFirestore db;
  const MonitoreoTab({super.key, required this.db});

  @override
  State<MonitoreoTab> createState() => _MonitoreoTabState();
}

class _MonitoreoTabState extends State<MonitoreoTab> {
  GoogleMapController? _mapController;
  final LatLng _initialPos = const LatLng(-11.9347, -76.6952); // Chosica
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Monitoreamos viajes en estado 'activo' (esperando) o 'en_camino' (ruta)
      stream: widget.db.collection('viajes')
          .where('estado', whereIn: ['activo', 'en_camino'])
          .snapshots(),
      builder: (context, snapshot) {
        // CP06: Manejo de error de conexión
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: CabifyColors.error, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar el monitoreo. Verifica tu conexión e inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CabifyColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];

        // CP05: Sin vehículos activos
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, color: Colors.grey[300], size: 80),
                const SizedBox(height: 20),
                const Text(
                  'No hay viajes activos en este momento.',
                  style: TextStyle(color: CabifyColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Los conductores aparecerán aquí cuando inicien un viaje.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Generar markers para los colectivos activos
        Set<Marker> markers = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ubicacion = data['ubicacionActual'] as Map<String, dynamic>?;
          if (ubicacion != null) {
            final lat = (ubicacion['lat'] as num).toDouble();
            final lng = (ubicacion['lng'] as num).toDouble();
            final estado = data['estado'];
            
            markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  estado == 'en_camino' ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueYellow
                ),
                infoWindow: InfoWindow(
                  title: data['conductorNombre'] ?? 'Conductor',
                  snippet: '${data['rutaLabel'] ?? 'Sin ruta'} · ${data['asientosOcupados']} PAX',
                ),
              ),
            );
          }
        }

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _initialPos, zoom: 11),
              onMapCreated: (c) => _mapController = c,
              markers: markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            // Panel lateral o inferior con lista rápida
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return _cardViaje(d, docs[i].id);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cardViaje(Map<String, dynamic> data, String id) {
    return GestureDetector(
      onTap: () {
        final u = data['ubicacionActual'] as Map<String, dynamic>?;
        if (u != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng((u['lat'] as num).toDouble(), (u['lng'] as num).toDouble()), 15)
          );
        }
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CabifyColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: CabifyColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.drive_eta, color: CabifyColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['conductorNombre'] ?? 'Conductor', 
                    style: const TextStyle(color: CabifyColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                  Text(data['vehiculo']?['placa'] ?? '-', 
                    style: const TextStyle(color: CabifyColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: CabifyColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
              child: Text('${data['asientosOcupados']}/${data['capacidad']}', 
                style: const TextStyle(color: CabifyColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
