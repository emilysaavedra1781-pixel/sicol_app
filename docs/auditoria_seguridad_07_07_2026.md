# Reporte de Auditoría de Seguridad - Proyecto SICOL
Fecha: 07/07/2026

## 1. Resumen de Gaps de Producto Implementados

| Gap | Descripción del Control Aplicado | Estado |
| :--- | :--- | :--- |
| Confirmación de llegada (Pasajero) | Se implementó el botón "YA BAJÉ" en `ReservaDetalleView` con geofencing de 100 metros. | ✅ Corregido |
| Vista de ETA para pasajero | Se añadió cálculo de tiempo estimado (ETA) en los widgets de mapa para el pasajero. | ✅ Corregido |
| Estado "no_show" | `cerrarViajeConDisponibilidad` ahora distingue pasajeros que nunca subieron (no_show) de los que llegaron (finalizada). | ✅ Corregido |

## 2. Resumen de Seguridad y Vulnerabilidades Corregidas

| Vulnerabilidad | Control Aplicado | Riesgo Anterior | Estado |
| :--- | :--- | :--- | :--- |
| Bypass de GPS en Producción | Se restringió el botón "Iniciar de todas formas" solo al modo `kDebugMode`. | **CRÍTICO** | ✅ Seguro |
| Viajes Huérfanos | Se implementó Cloud Function `abandonarViajesHuerfanos` que corre cada hora. | Medio | ✅ Seguro |
| Concurrencia en Reservas | Se verificó el uso de `db.runTransaction()` en todas las funciones críticas de reserva. | Medio | ✅ Seguro |
| Reglas de Firestore | Se creó `firestore.rules` con validaciones de rol y propiedad de documentos. | **ALTO** | ✅ Seguro |
| Acceso Público en Storage | Se creó `storage.rules` restringiendo acceso a documentos sensibles (DNI, Licencia). | **ALTO** | ✅ Seguro |
| Exposición de API Keys | Se añadió `firebase_options.dart` y otros archivos sensibles al `.gitignore`. | Medio | ✅ Seguro |

## 3. Inventario de Datos Críticos y Controles de Acceso

| Dato | Almacenamiento | Nivel de Sensibilidad | Protección Actual |
| :--- | :--- | :--- | :--- |
| **Foto DNI / Licencia** | Firebase Storage `/conductores/{uid}/documentos/` | **Muy Alta** | Restringido por `storage.rules` (Solo dueño y Admin). |
| **Ubicación en Tiempo Real** | Firestore `viajes/{id}/ubicacionActual` | **Alta** | Restringido por `firestore.rules` (Solo conductor o admin escriben). |
| **Celular / Email** | Firestore `usuarios/{uid}/` | Media | Protegido por `firestore.rules` (Solo dueño lee). |
| **Ingresos del Conductor** | Firestore `viajes/{id}/ingresoTotal` | Media | Protegido por reglas que impiden edición directa por el conductor. |
| **OTP de Recuperación** | Firestore / App UI | **Muy Alta** | **POR MEJORAR**: Se requiere integración con servicio de SMS real (Twilio/Firebase Auth SMS). |

## 4. Notas Finales y Próximos Pasos
Se recomienda desplegar las nuevas Reglas de Seguridad y las Cloud Functions de inmediato. El sistema de OTP de recuperación sigue siendo un punto de atención para una fase futura donde se use un proveedor de SMS real para evitar la simulación en pantalla.
