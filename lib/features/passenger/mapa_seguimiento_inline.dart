import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaSeguimientoInline extends StatefulWidget {
  final String viajeId;
  const MapaSeguimientoInline({super.key, required this.viajeId});

  @override
  State<MapaSeguimientoInline> createState() => _MapaSeguimientoInlineState();
}

class _MapaSeguimientoInlineState extends State<MapaSeguimientoInline> {
  GoogleMapController? _ctrl;
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
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('viajes').doc(widget.viajeId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator(color: Color(0xFF1E6BFF))),
          );
        }

        final viaje = snap.data!.data() as Map<String, dynamic>;
        final ubicacion = (viaje['ubicacionActual'] as Map?)?.cast<String, dynamic>();
        final ruta = viaje['ruta'] ?? 'chosica_lima';
        final lat = (ubicacion?['lat'] as num?)?.toDouble() ?? -11.9347;
        final lng = (ubicacion?['lng'] as num?)?.toDouble() ?? -76.6952;
        final pos = LatLng(lat, lng);
        final puntos = ruta == 'chosica_lima'
            ? _rutaChosicaLima
            : _rutaChosicaLima.reversed.toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ctrl?.animateCamera(CameraUpdate.newLatLng(pos));
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                  SizedBox(width: 4),
                  Text('Colectivo en vivo',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: pos, zoom: 12),
                  onMapCreated: (c) => _ctrl = c,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  markers: {
                    Marker(
                      markerId: const MarkerId('colectivo'),
                      position: pos,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      infoWindow: const InfoWindow(title: 'Colectivo'),
                    ),
                    Marker(
                      markerId: const MarkerId('destino'),
                      position: puntos.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: 'Destino'),
                    ),
                  },
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('ruta'),
                      points: puntos,
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