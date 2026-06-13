import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '/../../services/simulation_service.dart';
import '../constants/route_data.dart';




class MapTab extends StatelessWidget {
  final bool enCamino;
  final Map<String, dynamic>? ubicacion;
  final String ruta;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onIrAViaje;

  const MapTab({
    super.key,
    required this.enCamino,
    required this.ubicacion,
    required this.ruta,
    required this.onMapCreated,
    required this.onIrAViaje,
  });

  @override
  Widget build(BuildContext context) {
    if (!enCamino) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined, color: Color(0xFF6B7280), size: 48),
            const SizedBox(height: 12),
            const Text(
                'El mapa estará disponible\ncuando arranques el viaje',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onIrAViaje,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
              child: const Text('Ir a Viaje'),
            ),
          ]));
    }

    final lat = (ubicacion?['lat'] as num?)?.toDouble() ??
        (ruta == 'chosica_lima' ? -11.9347 : -12.0950);
    final lng = (ubicacion?['lng'] as num?)?.toDouble() ??
        (ruta == 'chosica_lima' ? -76.6952 : -77.0450);
    final posActual = LatLng(lat, lng);
    final rutaPuntos = ruta == 'chosica_lima'
        ? rutaChosicaLima
        : rutaChosicaLima.reversed.toList();
    final origen = SimulationService.labelOrigen(ruta);
    final destino = SimulationService.labelDestino(ruta);

    return Stack(children: [
      GoogleMap(
        initialCameraPosition:
        CameraPosition(target: posActual, zoom: 12),
        onMapCreated: onMapCreated,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: {
          Marker(
              markerId: const MarkerId('conductor'),
              position: posActual,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Colectivo')),
          Marker(
              markerId: const MarkerId('origen'),
              position: rutaPuntos.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: origen)),
          Marker(
              markerId: const MarkerId('destino'),
              position: rutaPuntos.last,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: destino)),
        },
        polylines: {
          Polyline(
              polylineId: const PolylineId('ruta'),
              points: rutaPuntos,
              color: const Color(0xFF1E6BFF),
              width: 4,
              patterns: [
                PatternItem.dash(20),
                PatternItem.gap(10)
              ]),
        },
      ),
      Positioned(
        bottom: 24,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12)
            ],
          ),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color:
                    const Color(0xFF1E6BFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.navigation_rounded,
                    color: Color(0xFF1E6BFF), size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ubicación simulada',
                          style: TextStyle(
                              color: Color(0xFF1E6BFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Text(
                          'Lat ${lat.toStringAsFixed(4)}  Lng ${lng.toStringAsFixed(4)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ])),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(children: [
                    const Icon(Icons.radio_button_checked,
                        color: Color(0xFF10B981), size: 10),
                    const SizedBox(width: 4),
                    Text(origen,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.flag_rounded,
                        color: Color(0xFFFF3B30), size: 10),
                    const SizedBox(width: 4),
                    Text(destino,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10)),
                  ]),
                ]),
          ]),
        ),
      ),
    ]);
  }
}