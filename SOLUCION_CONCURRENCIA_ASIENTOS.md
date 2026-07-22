# Solución Técnica: Gestión de Concurrencia en Reservas

Este documento detalla las medidas implementadas para resolver el problema de colisión de asientos cuando múltiples usuarios intentan reservar el mismo lugar simultáneamente.

---

## 1. El Problema (Condición de Carrera)
Anteriormente, si dos usuarios seleccionaban el mismo asiento al mismo tiempo, el backend permitía que ambos avanzaran al portal de pago si las peticiones llegaban casi juntas. Esto causaba que:
1. Uno de los pagos fallara silenciosamente.
2. El frontend se rompiera ("pantalla gris") al no saber manejar el error devuelto por la Cloud Function.
3. Se generaran inconsistencias en el mapa de asientos del vehículo.

## 2. Solución Implementada

### A. Backend: Transacciones Atómicas (`functions/index.js`)
Se ha envuelto la lógica de bloqueo de asientos en una **Transacción de Firestore** dentro de la función `bloquearYCrearPreferencia`.
*   **Lectura y Validación**: El sistema lee el mapa de asientos dentro de la transacción.
*   **Condición**: Si detecta que el estado de CUALQUIERA de los asientos seleccionados ya no es `'libre'`, la transacción aborta inmediatamente devolviendo `false`.
*   **Escritura**: Solo si todos los asientos están libres, se marcan como `'bloqueado'` de forma atómica.
*   **Error**: Si la transacción falla, se lanza un `HttpsError` con código `already-exists`.

### B. Frontend: Captura y Feedback de Errores (`seat_selection_view.dart`)
Se mejoró el manejo de excepciones al invocar la función de reserva:
*   **Try/Catch**: Ahora se captura específicamente el error del backend.
*   **Feedback UX**: Si el error es por concurrencia (`already-exists`), se muestra un SnackBar rojo con el mensaje: *"Uno de los asientos elegidos acaba de ser ocupado. Por favor elige otros."*
*   **Auto-Reset**: La vista limpia la selección actual automáticamente para permitir al usuario elegir otros asientos disponibles sin tener que reiniciar la app.

### C. Idempotencia en Webhooks (`functions/index.js`)
Se reforzó la lógica de los webhooks de pago para evitar el procesamiento doble de una misma transacción:
*   Se agregaron verificaciones de `paymentId` previos a la ejecución de la transacción de confirmación.
*   Esto previene que un reintento automático de Mercado Pago genere duplicidad en los ingresos del conductor o en el conteo de pasajeros.

## 3. Beneficios
1.  **Integridad de Datos**: El mapa de asientos del viaje siempre será consistente con la realidad de las reservas.
2.  **UX Superior**: El usuario recibe un mensaje de error claro en lugar de un crash de la aplicación.
3.  **Seguridad Financiera**: Se garantiza que un usuario solo pague por asientos que realmente ha logrado bloquear para sí mismo.

---
**Archivo generado el:** 07/07/2026
