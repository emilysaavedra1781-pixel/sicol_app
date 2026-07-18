import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParaderoData {
  final String nombre;
  final LatLng coordinates;

  const ParaderoData(this.nombre, this.coordinates);
}

const Map<String, List<ParaderoData>> paraderosConCoordenadas = {
  'chosica_lima': [
    ParaderoData('Plaza de Armas de Chosica', LatLng(-11.9347, -76.6952)),
    ParaderoData('Ñaña', LatLng(-11.9867, -76.8322)),
    ParaderoData('Huachipa', LatLng(-12.0125, -76.9036)),
    ParaderoData('Ate Vitarte', LatLng(-12.0233, -76.9247)),
    ParaderoData('La Molina', LatLng(-12.0733, -76.9447)),
    ParaderoData('Javier Prado', LatLng(-12.0833, -77.0147)),
    ParaderoData('Petit Thouars', LatLng(-12.0950, -77.0450)),
  ],
  'lima_chosica': [
    ParaderoData('Petit Thouars', LatLng(-12.0950, -77.0450)),
    ParaderoData('Javier Prado', LatLng(-12.0833, -77.0147)),
    ParaderoData('La Molina', LatLng(-12.0733, -76.9447)),
    ParaderoData('Ate Vitarte', LatLng(-12.0233, -76.9247)),
    ParaderoData('Huachipa', LatLng(-12.0125, -76.9036)),
    ParaderoData('Ñaña', LatLng(-11.9867, -76.8322)),
    ParaderoData('Plaza de Armas de Chosica', LatLng(-11.9347, -76.6952)),
  ],
};

const Map<String, List<String>> paraderosPorRuta = {
  'chosica_lima': [
    'Plaza de Armas de Chosica',
    'Ñaña',
    'Huachipa',
    'Ate Vitarte',
    'La Molina',
    'Javier Prado',
    'Petit Thouars',
  ],
  'lima_chosica': [
    'Petit Thouars',
    'Javier Prado',
    'La Molina',
    'Ate Vitarte',
    'Huachipa',
    'Ñaña',
    'Plaza de Armas de Chosica',
  ],
};
