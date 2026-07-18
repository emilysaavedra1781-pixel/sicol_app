import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'paraderos_constants.dart';
import '../../app_theme.dart';

class MapaSeguimientoWidget extends StatefulWidget {
  final String viajeId;
  final String? targetParadero;

  const MapaSeguimientoWidget({
    super.key, 
    required this.viajeId,
    this.targetParadero,
  });

  @override
  State<MapaSeguimientoWidget> createState() => _MapaSeguimientoWidgetState();
}

class _MapaSeguimientoWidgetState extends State<MapaSeguimientoWidget> {
  GoogleMapController? _mapController;
  final _db = FirebaseFirestore.instance;

  static const List<LatLng> _rutaChosicaLima = [
    LatLng(-11.9347, -76.6952),
    LatLng(-11.9280, -76.6750),
    LatLng(-11.9100, -76.6300),
    LatLng(-11.8900, -76.5800),
    LatLng(-11.9050, -76.9900),
    LatLng(-12.0200, -76.9500),
    LatLng(-12.0400, -76.9800),
    LatLng(-12.0650, -77.0000),
    LatLng(-12.0850, -77.0200),
    LatLng(-12.0900, -77.0350),
    LatLng(-12.0950, -77.0450),
  ];

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  LatLng? _getParaderoCoords(String? nombre, String? ruta) {
    if (nombre == null || ruta == null) return null;
    final list = paraderosConCoordenadas[ruta];
    if (list == null) return null;
    try {
      return list.firstWhere((p) => p.nombre == nombre).coordinates;
    } catch (_) {
      return null;
    }
  }

  String _calculateETA(double distanceMeters) {
    if (distanceMeters < 100) return "Llegando...";
    final minutes = (distanceMeters / 500).ceil();
    return "Llega en aprox. $minutes min";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('viajes').doc(widget.viajeId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
              child: CircularProgressIndicator(color: CabifyColors.primary));
        }

        final viaje = snapshot.data!.data() as Map<String, dynamic>;
        final ubicacion = (viaje['ubicacionActual'] as Map?)?.cast<String, dynamic>();
        final ruta = viaje['ruta'] ?? 'chosica_lima';
        final rutaLabel = viaje['rutaLabel'] ?? '';
        final lat = (ubicacion?['lat'] as num?)?.toDouble() ?? -11.9347;
        final lng = (ubicacion?['lng'] as num?)?.toDouble() ?? -76.6952;
        final posActual = LatLng(lat, lng);
        final rutaPuntos = ruta == 'chosica_lima'
            ? _rutaChosicaLima
            : _rutaChosicaLima.reversed.toList();

        String etaText = "";
        if (widget.targetParadero != null) {
          final targetCoords = _getParaderoCoords(widget.targetParadero, ruta);
          if (targetCoords != null) {
            final distance = Geolocator.distanceBetween(
              posActual.latitude, posActual.longitude,
              targetCoords.latitude, targetCoords.longitude,
            );
            etaText = _calculateETA(distance);
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(posActual));
        });

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(rutaLabel,
                        style: const TextStyle(
                            color: CabifyColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (etaText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        etaText,
                        style: const TextStyle(color: CabifyColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                      SizedBox(width: 4),
                      Text('En vivo',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: posActual, zoom: 13),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('colectivo'),
                      position: posActual,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      infoWindow: const InfoWindow(title: 'Colectivo'),
                    ),
                    Marker(
                      markerId: const MarkerId('destino'),
                      position: rutaPuntos.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: 'Destino'),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('ruta'),
                      points: rutaPuntos,
                      color: const Color(0xFF1E6BFF),
                      width: 4,
                      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                    ),
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
