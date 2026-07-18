# Detalle Técnico del Sistema de Notificaciones (SICOL)

Este documento describe el funcionamiento interno, los disparadores y el estado de implementación de las notificaciones push en el ecosistema SICOL (Flutter + Cloud Functions).

---

### 1. Pago Confirmado
*   **Disparador**: Webhook de Mercado Pago (`exports.webhookMercadoPago` en `functions/index.js`).
*   **Mecanismo**: Cuando Mercado Pago envía un POST indicando que el pago está `approved`, se ejecutan las funciones `registrarMultiReservaExitosa` o `registrarReservaExitosa`. 
*   **Envío**: Se envía desde el backend mediante `admin.messaging().send()`.
*   **Visualización del Pasajero**: Recibe una notificación con el título "Tu pago fue confirmado" y el cuerpo detallando el asiento reservado (ej: "Asiento 2 reservado con éxito.").
*   **Estado**: ✅ Implementada.

### 2. Nueva Reserva
*   **Obtención de Token**: El sistema consulta el documento del viaje para obtener el `conductorUid`. Luego busca en la colección `usuarios` el documento con ese UID para extraer el campo `fcmToken`.
*   **Momento de Envío**: Se envía **inmediatamente después** de confirmar y registrar el pago en la base de datos (dentro de la misma lógica del webhook).
*   **Estado**: ✅ Implementada.

### 3. Colectivo Lleno
*   **Detección**: Se evalúa al final de `registrarReservaExitosa`.
*   **Lógica**: Verifica si `vData.asientosOcupados >= vData.capacidad`.
*   **Condición**: Solo se dispara si el viaje tiene el estado `activo` (indicando que aún no ha arrancado).
*   **Estado**: ✅ Implementada.

### 4. Reserva por expirar / Reserva expirada
*   **Scheduler**: La función `exports.verificarExpiracionBloqueos` corre mediante un cron job **cada 1 minuto** (`onSchedule("every 1 minutes")`).
*   **Duración del Bloqueo**: El bloqueo inicial se configura por **10 minutos**.
*   **Aviso**: Envía un push 2 minutos antes de que expire si el estado sigue siendo `bloqueada`.
*   **Acción Automática**: Al expirar, la función `liberarAsientoBloqueado` ejecuta una transacción que libera el asiento en el viaje y marca la reserva como `expirada`.
*   **Estado**: ✅ Implementada.

### 5. Cambio de ruta
*   **Mecanismo**: Es un reporte **manual**. No hay detección automática por GPS.
*   **Flujo**: El conductor debe ir a la sección de incidencias en su app y seleccionar "Desvío de ruta".
*   **Archivo**: `functions/index.js` maneja el trigger `exports.triggerNotificarIncidencia`.
*   **Estado**: ✅ Implementada.

### 6. Retraso en llegada
*   **Implementación**: Sí, integrada en el módulo de incidencias.
*   **Disparador**: Reporte manual del conductor de tipo "Retraso".
*   **Lógica**: Dispara la notificación solo si el campo `minutosRetraso` es **>= 5**.
*   **Cálculo**: El conductor selecciona el tiempo estimado mediante un Slider (de 1 a 30 min) en la pantalla `ReportarIncidenciaView`.
*   **Estado**: ✅ Implementada.

### 7. Viaje finalizado
*   **Disparador**: El conductor presiona "Finalizar viaje" en la vista `DriverTripView`, lo que actualiza el estado del viaje a `finalizado`.
*   **Flujo Flutter**: La app del pasajero tiene un listener en `notification_service.dart`. Si detecta `tipo: 'viaje_finalizado'`, usa el `Navigator` para abrir `CalificacionView`.
*   **App Cerrada**: Sí funciona. Se captura en `getInitialMessage` al abrir la app desde el banner de notificación.
*   **Estado**: ✅ Implementada.

### 8. Asiento liberado
*   **Destinatario**: Llega **únicamente a los otros pasajeros que ya tienen una reserva confirmada en ese mismo viaje**.
*   **Propósito**: Invitarlos a cambiarse a un asiento que podría ser más cómodo o preferente.
*   **Estado**: ✅ Implementada.

### 9. Colectivo llegando (GPS)
*   **Verificación**: Se dispara por el trigger `onDocumentUpdated` de la colección `viajes` cada vez que el conductor actualiza su posición.
*   **Umbral**: Se considera "llegando" cuando la distancia es **<= 300 metros** del paradero asignado al pasajero.
*   **Cálculo**: Se realiza en el servidor usando la fórmula de Haversine para mayor precisión.
*   **Estado**: ✅ Implementada.

### 10. Recordatorio 30 minutos antes
*   **Funcionamiento**: El scheduler `enviarRecordatoriosViaje` corre **cada 5 minutos**.
*   **Detección de Hora**: Utiliza el campo `fechaSalida` (Timestamp) de Firestore.
*   **Rango**: Busca viajes que salgan en una ventana de entre 25 y 35 minutos a futuro.
*   **Estado**: ✅ Implementada.

### 11. Cancelación de reserva
*   **Asiento disponible**: Sí, el método `cancelarReserva` en Flutter ejecuta una transacción que libera el asiento en el viaje inmediatamente.
*   **Reembolso**: **❌ No implementado**. Actualmente, el sistema solo marca el estado como `cancelada` e informa que no hay devoluciones.
*   **Estado**: ⚠️ Parcialmente (Falta reembolso automático).

### 12. Nuevo conductor pendiente
*   **FCM del Admin**: La función `notificarNuevoConductorPendiente` obtiene los tokens de la colección `admins`.
*   **Destinatarios**: Se envía a **todos** los administradores que tengan un token registrado, permitiendo una gestión multi-admin.
*   **Estado**: ✅ Implementada.
