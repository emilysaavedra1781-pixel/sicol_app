# Solución Técnica: Fallback por Timeout de GPS (Llegada Simulada)

Este documento explica la implementación del mecanismo de seguridad para evitar que un pasajero quede bloqueado en la pantalla de "En trayecto" cuando el GPS no detecta movimiento real o el conductor se queda estático.

---

## 1. El Problema
En el flujo normal, el botón **"YA BAJÉ"** solo se habilita cuando el GPS del pasajero detecta que está a menos de 100 metros del destino. Si el GPS falla, pierde precisión, o el vehículo no se mueve (simulación o tráfico extremo), el pasajero nunca puede finalizar su viaje, quedando atrapado en el estado "Abordado".

## 2. La Solución (Fallback)
Se ha implementado una capa de respaldo que convive con el GPS real. Si el sistema detecta que el pasajero está "a bordo" pero no hay cambios significativos de posición durante un tiempo determinado, el sistema asume una "llegada técnica" para permitir que el flujo continúe.

### Componentes de la implementación:

#### A. Detección de Inactividad (App Pasajero)
*   **Umbral de Movimiento**: 10 metros.
*   **Tiempo de Espera**: 2 minutos.
*   **Lógica**: La app monitorea constantemente la posición. Si la distancia entre la posición actual y la última registrada es menor a 10 metros durante 2 minutos seguidos, se dispara el fallback.

#### B. Sincronización en Firestore
Cuando se cumple el tiempo de espera o el GPS llega al destino real, se actualizan los siguientes campos en la colección `reservas/{id}`:
*   `habilitarBajada`: `true` (Habilita el botón en la UI).
*   `llegadaSimulada`: `true` (Solo si fue por timeout).
*   `llegadaRealGps`: `true` (Solo si fue por proximidad física).
*   `fechaSimulacion` / `fechaLlegadaGps`: Timestamp para auditoría.

#### C. Notificaciones Push (Cloud Functions)
Se creó la función `notificarHabilitacionBajada` que reacciona al cambio del campo `habilitarBajada`.
*   **Si es llegada real**: Notifica al usuario que ya está en su paradero.
*   **Si es por timeout**: Notifica que se detectó la llegada y puede confirmar su bajada manualmente.

---

## 3. Beneficios
1.  **UX Robusta**: El usuario nunca se queda bloqueado, incluso en zonas de mala señal o túneles.
2.  **Trazabilidad**: El Administrador puede ver en Firestore qué viajes se completaron por GPS real y cuáles requirieron el uso del fallback (campo `llegadaSimulada`).
3.  **Persistencia**: Al guardar el estado en la base de datos, si el usuario reinicia su teléfono, el botón seguirá habilitado al volver a entrar.

## 4. Archivos Modificados
*   `lib/features/passenger/reserva_detalle_view.dart`: Lógica de timers y monitoreo de posición.
*   `functions/index.js`: Trigger de notificación push para el aviso de llegada.
