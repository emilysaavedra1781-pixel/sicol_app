# Bitácora de Progreso — Testing SICOL

## Resumen General
- Total de módulos identificados: 23
- Módulos completados: 14 (RF-NEW parcial, RF05, RF02, RF40, RF01, RF06, RF07+RF50, RF08, RF09, RF13 parcial, RF23+RF46, RF34+RF33+RF42, RF03, RF11+RF28+RF41)
- Módulos pendientes: 9
- Total de casos de prueba (CPs): 71

## Detalle por Módulo
| Módulo | RF cubierto | Archivo de test | CPs totales | CPs pasando | Estado | Observaciones |
|---|---|---|---|---|---|---|
| 1 | RF-NEW | test/rf_new_paraderos_test.dart | 3 | 3 | ⚠️ Parcial | CP02-CP09 requieren tests de integración de UI/Admin |
| 2 | RF05 | test/rf_new_paraderos_test.dart | 4 | 4 | ✅ Completo | Incluye validación de filtrado y fallback |
| 3 | RF02 | test/rf02_login_pasajero_test.dart | 5 | 5 | ✅ Completo | Cubre flujo exitoso, errores y bloqueos |
| 4 | RF40 | test/rf02_login_pasajero_test.dart | 4 | 4 | ✅ Completo | Cubre bloqueo automático y desbloqueo |
| 5 | RF01 | test/rf01_registro_pasajero_test.dart | 5 | 5 | ✅ Completo | Cubre flujo exitoso, validaciones y red |
| 6 | RF06 | test/rf06_seleccion_colectivo_test.dart | 4 | 4 | ✅ Completo | Cubre listado, lista vacía y concurrencia |
| 7 | RF07+RF50 | test/rf07_rf50_compra_asientos_test.dart | 4 | 4 | ✅ Completo | Bloqueo temporal, múltiples viajeros y validación |
| 8 | RF08 | test/rf08_confirmacion_compra_test.dart | 4 | 4 | ✅ Completo | Resumen de compra, cancelación manual y expiración |
| 9 | RF09 | test/rf09_pago_division_test.dart | 3 | 3 | ✅ Completo | Comprobante, concurrencia y monitoreo de estado |
| 10 | RF13 | test/rf13_registro_admin_conductor_test.dart | 9 | 9 | ⚠️ Parcial | Registro, edición, aprobación y duplicados |
| 11 | RF23+RF46 | test/rf23_rf46_login_recuperacion_conductor_test.dart | 6 | 6 | ✅ Completo | Login conductor, bloqueo y recuperación con OTP |
| 12 | RF34+RF33+RF42 | test/rf15_ejecucion_viaje_test.dart | 6 | 6 | ✅ Completo | Geofencing, bloqueo simultáneo y arranque de viaje |
| 13 | RF03 | test/rf03_recuperacion_pasajero_test.dart | 5 | 5 | ✅ Completo | Flujo exitoso, errores de OTP y red |
| 14 | RF11+RF28+RF41 | test/rf11_rf28_rf41_cancelacion_pasajero_test.dart | 9 | 4 | ⚠️ Parcial | Cancelación y reasignación OK. RF41 pendiente (UI) |
| 15 | RF14+RF19+RF27 | test/rf14_seguimiento_eta_test.dart | 6 | 3 | ⚠️ Parcial | ETA validado. Proximidad y Retraso dependen de Backend. |

## Deuda Técnica Pendiente
- **UI Testing**: La mayoría de la lógica de reordenamiento de paraderos (RF-NEW CP04, CP05) está en widgets de Flutter y requiere `flutter_test` con `pumpWidget` y simulaciones de gestos.
- **Network Errors**: Los tests actuales usan mocks que siempre retornan datos o errores controlados; falta testear el comportamiento ante `SocketException` reales.
- **Integration Tests**: No hay pruebas que cubran el flujo completo desde el backend (Functions) hasta la app.

## Próximo Módulo a Trabajar
Módulo: **RF14 — Seguimiento y ETA**
Cubre: Notificación de proximidad, tiempo de llegada y alertas de retraso.
