# Estado de Notificaciones Push (SICOL)
Fecha: 07/07/2026

Este documento detalla la auditoría del sistema de notificaciones push, indicando qué lógicas están completas y cuáles han sido implementadas/ajustadas.

## 1. Notificaciones sin GPS (Completas)

| Notificación | Estado | Descripción técnica |
| :--- | :--- | :--- |
| **Pago Confirmado** | ✅ Funciona | Enviada desde `webhookMercadoPago` tras recibir estado `approved`. |
| **Nueva Reserva** | ✅ Funciona | Disparada inmediatamente después de procesar el pago en el backend. |
| **Colectivo Lleno** | ✅ Funciona | Verifica `asientosOcupados >= capacidad` al final de cada reserva exitosa. |
| **Reserva por Expirar / Expirada** | ✅ Funciona | Cron job `verificarExpiracionBloqueos` corre cada 1 min. Libera asientos automáticamente. |
| **Viaje Finalizado** | ✅ Funciona | Trigger `notificarViajeFinalizado` al cambiar estado de viaje a `finalizado`. |
| **Cancelación de Reserva** | ✅ Funciona | Trigger `notificarCancelacionReserva` avisa al conductor. |
| **Nuevo Conductor Pendiente** | ✅ Funciona | Trigger en `usuarios/{userId}` cuando el estado es `pendiente_aprobacion`. |
| **Retraso (desde Incidencias)** | ✅ Funciona | Trigger `triggerNotificarIncidencia` si el retraso es >= 5 min. |
| **Desvío de Ruta (Incidencias)** | ✅ Funciona | Trigger `triggerNotificarIncidencia` cuando el tipo es "Desvío de ruta". |

## 2. Notificaciones de Simulación (Debug)

He creado funciones callables y botones en la UI para permitir pruebas manuales sin depender de eventos reales.

| Notificación | Botón / Función | Estado |
| :--- | :--- | :--- |
| **Colectivo Llegando (300m)** | `simularColectivoLlegando` | ✅ Implementada |
| **Recordatorio 30 min** | `simularRecordatorio` | ✅ Implementada |

**Cómo probar (Modo Debug):**
En `DriverHomeView` (Pantalla de inicio del conductor), al final de la vista, verás la sección "HERRAMIENTAS DE SIMULACIÓN". Solo visibles si la app corre en `kDebugMode`.

## 3. Notificaciones Agregadas / Ajustadas

| Notificación | Cambio realizado | Estado |
| :--- | :--- | :--- |
| **Forzar cancelación de viaje (Admin)** | Implementado botón "CANCELAR (ADMIN)" en `ViajesTab`. Llama a `forzarCancelacionViajeAdmin` notificando a todos los pasajeros y liberando asientos. | ✅ Implementada |
| **Asiento Liberado** | Se verificó que `notificarCancelacionReserva` ya incluye la lógica para avisar a otros pasajeros del mismo viaje si el estado es `activo`. | ✅ Funciona |

---

## 🛠️ Detalle de Implementación Reciente

### Forzar Cancelación de Viaje (Admin)
Se ha implementado la función que permite al Administrador detener un viaje activo por motivos de seguridad o error.
- **Backend**: `functions/index.js` -> `forzarCancelacionViajeAdmin`.
- **UI**: `lib/features/admin/tabs/viajes_tab.dart`.
- **Acción**: Actualiza estado de viaje a `cancelado_admin`, libera al conductor (`disponible: true`) y marca todas las reservas asociadas como `cancelada_viaje`.
- **Push**: Los pasajeros reciben: *"🚨 Viaje cancelado: Tu viaje con [Nombre Conductor] ha sido cancelado por el administrador. Se liberó tu asiento."*

### Simulación de Eventos
Se agregaron herramientas para el equipo de QA:
1. **Llegada**: `simularColectivoLlegando(viajeId, pasajeroId)` permite ver el aviso de "Prepárate" instantáneamente.
2. **Recordatorio**: `simularRecordatorio(viajeId)` envía el push de "Tu viaje sale pronto" a todos los pasajeros confirmados de ese viaje.
