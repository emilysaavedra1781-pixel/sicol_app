// test/features/passenger/select_pickup/select_pickup_controller_test.dart
//
// TDD — RF05: Selección de Punto de Recojo
// Pruebas unitarias escritas para validar el controlador antes de la UI.
// Cubren: caso exitoso, selección completa, autocompletado, EA01 (GPS off).
//
// Para ejecutar: flutter test test/features/passenger/select_pickup/

import 'package:flutter_test/flutter_test.dart';
import 'package:sicol_app/features/passenger/select_pickup/select_pickup_controller.dart';
import 'package:sicol_app/models/paradero_model.dart';
import 'package:sicol_app/services/paradero_service.dart';

// ─── Stub DAO para tests (no toca Firestore) ─────────────────────────────────
class _MockParaderoService extends ParaderoService {
  @override
  Future<List<ParaderoModel>> getParaderosActivos({
    String ruta = 'chosica_lima',
  }) async {
    return [
      ParaderoModel(
        id: 'p01', nombre: 'Chosica Centro',
        referencia: 'Plaza de Armas', ruta: 'chosica_lima', orden: 1,
      ),
      ParaderoModel(
        id: 'p02', nombre: 'Ate Vitarte',
        referencia: 'Óvalo de Ate', ruta: 'chosica_lima', orden: 2,
      ),
      ParaderoModel(
        id: 'p03', nombre: 'La Molina',
        referencia: 'Av. La Molina', ruta: 'chosica_lima', orden: 3,
      ),
    ];
  }
}

void main() {
  group('RF05 — SelectPickupController', () {
    late SelectPickupController ctrl;

    setUp(() {
      ctrl = SelectPickupController(service: _MockParaderoService());
    });

    tearDown(() => ctrl.dispose());

    // ─── Test 1: Carga paraderos correctamente ────────────────────────────
    test('Carga paraderos desde el servicio', () async {
      await ctrl.cargarParaderos();
      expect(ctrl.paraderos.length, 3);
      expect(ctrl.cargando, false);
    });

    // ─── Test 2: Selección de punto de recojo ─────────────────────────────
    test('Selecciona punto de recojo', () async {
      await ctrl.cargarParaderos();
      final p = ctrl.paraderos.first;
      ctrl.seleccionarRecojo(p);
      expect(ctrl.recojo?.id, 'p01');
      expect(ctrl.seleccionCompleta, false); // falta destino
    });

    // ─── Test 3: Selección completa habilita confirmar ────────────────────
    test('Selección completa cuando recojo y destino son distintos', () async {
      await ctrl.cargarParaderos();
      ctrl.seleccionarRecojo(ctrl.paraderos[0]);
      ctrl.seleccionarDestino(ctrl.paraderos[2]);
      expect(ctrl.seleccionCompleta, true);
    });

    // ─── Test 4: No permite mismo paradero como recojo y destino ──────────
    test('Seleccionar destino igual al recojo limpia el destino anterior', () async {
      await ctrl.cargarParaderos();
      final p = ctrl.paraderos.first;
      ctrl.seleccionarRecojo(p);
      ctrl.seleccionarDestino(ctrl.paraderos[1]);
      // ahora seleccionamos como recojo el mismo que destino
      ctrl.seleccionarRecojo(ctrl.paraderos[1]);
      expect(ctrl.destino, null); // debe limpiarse
    });

    // ─── Test 5: Autocompletado filtra correctamente ──────────────────────
    test('Filtrar sugerencias por nombre', () async {
      await ctrl.cargarParaderos();
      ctrl.filtrarSugerencias('molina');
      expect(ctrl.sugerencias.length, 1);
      expect(ctrl.sugerencias.first.nombre, 'La Molina');
    });

    // ─── Test 6: Limpiar sugerencias ─────────────────────────────────────
    test('Limpiar sugerencias vacía la lista', () async {
      await ctrl.cargarParaderos();
      ctrl.filtrarSugerencias('ate');
      expect(ctrl.sugerencias.isNotEmpty, true);
      ctrl.limpiarSugerencias();
      expect(ctrl.sugerencias.isEmpty, true);
    });

    // ─── Test 7: EA01 GPS desactivado retorna false ───────────────────────
    test('EA01: capturarUbicacionGPS retorna false si GPS desactivado', () async {
      ctrl.setGpsActivo(false);
      final resultado = await ctrl.capturarUbicacionGPS();
      expect(resultado, false);
    });

    // ─── Test 8: GPS activo retorna true ─────────────────────────────────
    test('capturarUbicacionGPS retorna true con GPS activo', () async {
      ctrl.setGpsActivo(true);
      final resultado = await ctrl.capturarUbicacionGPS();
      expect(resultado, true);
    });

    // ─── Test 9: Limpiar selección ────────────────────────────────────────
    test('limpiar() resetea recojo y destino', () async {
      await ctrl.cargarParaderos();
      ctrl.seleccionarRecojo(ctrl.paraderos[0]);
      ctrl.seleccionarDestino(ctrl.paraderos[1]);
      ctrl.limpiar();
      expect(ctrl.recojo, null);
      expect(ctrl.destino, null);
    });
  });
}
