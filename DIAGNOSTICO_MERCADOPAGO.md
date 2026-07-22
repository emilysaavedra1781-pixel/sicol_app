# Diagnóstico Técnico: Integración Mercado Pago y Reservas

Este documento detalla la causa raíz de los errores detectados en el flujo de pagos y cancelaciones del sistema SICOL.

---

## 1. Las notificaciones de pago no llegan (Webhooks)

**Causa Raíz:**
La función `webhookMercadoPago` en `functions/index.js` (Firebase Functions V2) no tiene configurado el acceso público. Por defecto, Google Cloud bloquea las peticiones externas a funciones V2 a menos que se especifique lo contrario. Mercado Pago recibe un error **403 Forbidden**.

**Impacto:**
*   Las reservas nunca cambian de estado a "confirmada".
*   No se generan los códigos de acceso (QR/Texto).
*   El conductor no recibe la notificación de "Nueva reserva".

**Solución Propuesta:**
Actualizar la definición de la función para permitir invocaciones públicas:
```javascript
exports.webhookMercadoPago = onRequest({ secrets: ["MP_ACCESS_TOKEN"], invoker: "public" }, async (req, res) => { ... });
```

---

## 2. Pantalla de reservas "no carga" tras el pago

**Causa Raíz:**
Es una consecuencia directa del **Problema 1**. La pantalla `ResumenReservasSesionView` se queda esperando a que los documentos en la colección `reservas` se actualicen con el estado `confirmada` y el `codigoVerificacion`. Al no llegar el Webhook, los datos en Firestore nunca cambian, dejando al usuario con una vista vacía o con datos provisionales (`-----`).

**Impacto:**
UX deficiente; el pasajero cree que el sistema falló aunque el dinero haya sido descontado.

**Solución Propuesta:**
Corregir el Webhook. Una vez que Firestore reciba la actualización del backend, la pantalla se refrescará automáticamente en milisegundos gracias al `StreamBuilder`.

---

## 3. Al cancelar una reserva se cancela TODO el viaje

**Causa Raíz:**
1.  **Backend:** La función `forzarCancelacionViajeAdmin` en `functions/index.js` está programada para marcar **todas** las reservas del viaje como `cancelada_viaje` y liberar al conductor.
2.  **UI Administrador:** En `viajes_tab.dart`, no existen botones de cancelación individual en la lista de pasajeros. El único botón disponible es el de "Anular Viaje" completo.
3.  **UI Pasajero:** Se debe verificar si el botón de cancelación individual está redirigiendo por error a una lógica de anulación total o si el trigger de base de datos está mal configurado.

**Impacto:**
Pérdida crítica de datos y afectación a pasajeros que no solicitaron cancelación.

**Solución Propuesta:**
*   **En Admin:** Modificar la lista de pasajeros en `ViajesTab` para incluir un botón de "X" o "Eliminar" por cada asiento. Este botón debe llamar a `bookingService.forzarCancelacionAdmin` (que ya existe en el código de Flutter) la cual actúa solo sobre UN `reservaId`.
*   **En Backend:** Asegurar que los triggers de `onUpdate` de reservas no disparen cierres de viaje a menos que sea la última reserva activa (si aplica).

---

## Estado de Archivos Afectados
*   `functions/index.js`: Requiere cambio de permisos en Webhook.
*   `lib/features/admin/tabs/viajes_tab.dart`: Requiere botones de acción individual.
*   `ESTADO_NOTIFICACIONES.md`: Debe actualizarse tras aplicar las correcciones.
