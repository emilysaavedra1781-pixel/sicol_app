# Resumen de Cierre de Pendientes Técnicos (SICOL)

Este documento detalla las mejoras de seguridad, flujos operativos y trazabilidad implementadas para resolver los cuellos de botella detectados en los módulos de Reservas, GPS y Panel Administrativo.

---

## 1. Mejoras en el Flujo de Cancelación
Se resolvió la imposibilidad de gestionar bajas individuales de pasajeros, lo cual anteriormente derivaba en la anulación innecesaria de viajes completos.

*   **Cancelación Individual (Admin):** Se agregó un botón de acción ("X") en la lista de pasajeros dentro de `ViajesTab`. Ahora el administrador puede liberar un asiento específico.
*   **Lógica Atómica:** Se utiliza `bookingService.forzarCancelacionAdmin`, asegurando que solo se modifique la reserva seleccionada y se actualice el conteo de asientos del viaje sin afectar a otros usuarios.
*   **Validación de Usuario:** Se confirmó que el pasajero ya contaba con un flujo de cancelación individual robusto en su aplicación.

## 2. Robustez del GPS (Mecanismos de Fallback)
Se implementó un sistema de "Llegada Técnica" para mitigar fallos de señal GPS o falta de movimiento detectado por el sistema operativo, evitando bloqueos en la interfaz.

*   **Fallback Conductor:** Si el vehículo no se mueve más de **10 metros en 2 minutos**, se habilita automáticamente el botón "Terminar Viaje" en `DriverTripView`.
*   **Fallback Pasajero:** Si no hay movimiento detectado, se habilita el botón "Ya bajé" en `ReservaDetalleView`, permitiendo al usuario finalizar su flujo.
*   **Sincronización:** Los estados de fallback se guardan en Firestore (`llegadaSimulada: true`), permitiendo que el estado persista incluso si la app se cierra y se vuelve a abrir.

## 3. Trazabilidad y Notificaciones
*   **Push Inteligentes:** La Cloud Function `notificarHabilitacionBajada` ahora distingue el motivo de la llegada para informar al usuario si debe actuar manualmente por timeout.
*   **Auditoría:** Se registran timestamps de simulación (`fechaSimulacion`) para permitir al equipo de operaciones identificar conductores o zonas con problemas recurrentes de señal.

---

## 💡 Recomendaciones del Desarrollador

1.  **Monitoreo de Abuso:** Aunque el fallback automático mejora la UX, se recomienda que el Administrador revise semanalmente en Firestore cuántos viajes tienen `llegadaSimulada: true`. Un número muy alto en un mismo conductor podría indicar que está apagando el GPS intencionalmente.
2.  **Ajuste de Umbrales:** Si el sistema se activa demasiado pronto en zonas de alto tráfico, se puede subir el timeout de **2 a 4 minutos** en las constantes de `driver_trip_view.dart` y `reserva_detalle_view.dart`.
3.  **Seguridad de Webhooks:** Verificar que el endpoint de Mercado Pago en Firebase Functions sea **público** (`invoker: "public"`) para asegurar la recepción de confirmaciones de pago en producción.

---

## 🚀 Pasos a Seguir (Checklist)

- [ ] **Despliegue de Backend:** Ejecutar `firebase deploy --only functions` para activar el nuevo trigger de notificación de llegada.
- [ ] **Prueba en Dispositivo Real:** Realizar un viaje de prueba y dejar el teléfono estático por 2 minutos para confirmar que el botón "Terminar Viaje" se habilita correctamente.
- [ ] **Mercado Pago:** Acceder al *Panel de Monitoreo* (Sección Beta en Developers) para validar que no haya errores 403 en los intentos de notificación IPN.
- [ ] **QA de Cancelación:** Crear un viaje con 3 pasajeros y cancelar solo el del medio desde el Panel Admin; verificar que los otros 2 códigos de acceso sigan siendo válidos.

**Archivo generado el:** 07/07/2026
