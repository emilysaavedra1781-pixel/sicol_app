# Sistema de Notificaciones Push (SICOL)

Este documento detalla la implementación de notificaciones push utilizando Firebase Cloud Messaging (FCM) en el proyecto SICOL.

## 1. Notificaciones Existentes

A continuación se listan las notificaciones implementadas, su disparador y destinatario:

| Nombre | Evento Disparador | Destinatario |
| :--- | :--- | :--- |
| **Pago Confirmado** | Éxito en transacción de Mercado Pago (webhook). | Pasajero |
| **Nueva Reserva** | Pasajero completa el pago de un asiento. | Conductor |
| **Colectivo Lleno** | El viaje alcanza su capacidad máxima tras una reserva. | Conductor |
| **⏳ Reserva por expirar** | Faltan 2 minutos para que expire el bloqueo temporal del asiento. | Pasajero |
| **❌ Reserva expirada** | El tiempo de bloqueo terminó sin completar el pago. | Pasajero |
| **Cambio en tu ruta** | El conductor registra un desvío de la ruta original. | Pasajeros del viaje |
| **⚠️ Retraso en llegada** | El conductor registra un retraso (>= 5 min). | Pasajeros del viaje |
| **Nuevo conductor** | Un usuario se registra como conductor (pendiente aprobación). | Administradores |
| **✅ Viaje finalizado** | El conductor cierra el viaje al llegar al destino. | Pasajeros (invita a calificar) |
| **Cancelación de reserva** | Un pasajero cancela su asiento confirmado. | Conductor |
| **🪑 Asiento disponible** | Se libera un asiento en un viaje donde ya tengo una reserva. | Otros pasajeros del viaje |
| **🚌 Colectivo llegando** | El bus está a menos de 300m del paradero del pasajero. | Pasajero |
| **✅ Tu colectivo llegó** | El conductor marca manualmente su llegada al paradero. | Pasajero |
| **🚌 Tu viaje sale pronto** | Faltan 30 minutos para la hora de salida programada. | Pasajeros confirmados |

## 2. Origen del Envío

Todas las notificaciones se envían desde el **Backend** para asegurar la entrega y centralizar la lógica:

*   **Cloud Functions (Firestore Triggers)**: Se disparan automáticamente cuando un documento cambia (`onDocumentUpdated`) o se crea (`onDocumentCreated`). Ejemplos: `notificarCancelacionReserva`, `triggerNotificarIncidencia`.
*   **Cloud Functions (Scheduled)**: Se ejecutan mediante cron jobs (`onSchedule`). Ejemplos: `verificarExpiracionBloqueos` (cada 1 min), `enviarRecordatoriosViaje` (cada 5 min).
*   **Cloud Functions (HTTPS/Callables)**: Disparadas por acciones manuales del usuario. Ejemplo: `notificarLlegadaManual`.

## 3. Conexión en Flutter

El servicio encargado de gestionar la recepción es `lib/services/notification_service.dart`.

*   **Escucha en Foreground**: Las notificaciones aparecen como un `SnackBar` personalizado (color azul `#1E6BFF`) mientras la app está abierta.
*   **Reacción al Tap (Background/Terminated)**:
    *   Si el tipo es `viaje_finalizado`: Navega automáticamente a `CalificacionView`.
    *   Si el tipo es `asiento_liberado`: Muestra un `AlertDialog` para que el pasajero decida si quiere reasignar su asiento.

## 4. Flujo Completo de una Notificación

1.  **Trigger**: Ocurre un evento en la base de datos (ej. Conductor cierra viaje).
2.  **Lógica Backend**: La Cloud Function `notificarViajeFinalizado` captura el cambio, busca los `fcmToken` de los pasajeros en la colección `usuarios` y construye el payload.
3.  **Transporte**: Firebase Messaging envía el mensaje al dispositivo físico.
4.  **Recepción**:
    *   *Foreground*: `notification_service.dart` intercepta el `RemoteMessage` y muestra un SnackBar.
    *   *Background*: El SO muestra el banner nativo. Al tocarlo, `onMessageOpenedApp` detecta el `tipo` y redirige a la vista correspondiente.

## 5. Notificaciones Faltantes (Sugerencias)

1.  **⚠️ Inicio de Viaje Forzado**: Avisar al conductor si el Admin inició su viaje remotamente.
2.  **💸 Resumen de Ingresos**: Notificar al conductor el monto total ganado al finalizar un viaje.
3.  **🚫 Cuenta Bloqueada/Rechazada**: Notificar al usuario si el Admin bloqueó su cuenta o rechazó sus documentos.
4.  **💬 Mensajería**: Notificar si hay un nuevo mensaje de chat entre conductor y pasajero (si se implementa chat).

## 6. Tabla Resumen de Implementación

| Notificación | Disparador | Destinatario | Vista conectada | Estado |
| :--- | :--- | :--- | :--- | :--- |
| Pago Confirmado | Webhook MP | Pasajero | SnackBar | Implementada |
| Nueva Reserva | Webhook MP | Conductor | SnackBar | Implementada |
| Viaje Finalizado | Trigger Firestore | Pasajero | `CalificacionView` | Implementada |
| Asiento Liberado | Trigger Firestore | Pasajero | `AlertDialog` | Implementada |
| Colectivo Llegando | Trigger GPS | Pasajero | SnackBar | Implementada |
| Recordatorio Salida | Scheduler (5m) | Pasajero | SnackBar | Implementada |
| Nuevo Cond. Pendiente| Trigger Firestore | Admin | SnackBar | Implementada |
| Ingreso de Dinero | Manual/Admin | Conductor | - | Falta |
