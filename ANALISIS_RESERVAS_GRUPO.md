# Análisis de Sistema: Reservas Grupales y Validación (SICOL)

Este documento detalla el análisis del problema detectado en el flujo de reservas grupales, específicamente la visibilidad de los códigos de verificación individuales ("Código Foto") y su relación con el código de agrupación ("Código Encuentro").

---

## 1. Problema Detectado
Cuando un pasajero realiza una reserva de múltiples asientos (ej. 8 asientos), el sistema procesa el pago correctamente, pero al finalizar el flujo, no se presentan de forma clara y vinculada los códigos individuales de cada integrante del grupo. Esto dificulta la validación por parte del conductor y la gestión del titular de la reserva.

## 2. Archivos y Funciones Revisados
Para este análisis se auditaron los siguientes componentes:

*   **Frontend (Flutter):**
    *   `lib/features/passenger/seat_selection_view.dart`: Selección de múltiples asientos y llamada a la función de bloqueo.
    *   `lib/features/passenger/resumen_compra_view.dart`: Pantalla previa al pago que lista los asientos elegidos.
    *   `lib/features/passenger/resumen_reservas_sesion_view.dart`: Vista final que debería mostrar todos los códigos post-pago.
    *   `lib/features/driver/tabs/passengers_tab.dart`: Vista del conductor donde se agrupan los pasajeros por ID de reserva.
*   **Backend (Cloud Functions):**
    *   `functions/index.js` -> `bloquearYCrearPreferencia`: Generación del `reservaGroupId`.
    *   `functions/index.js` -> `registrarMultiReservaExitosa`: Generación de los códigos de verificación individuales tras el pago.

## 3. Comportamiento Actual
1.  El sistema genera un `reservaGroupId` (interno) para agrupar los asientos en una sola transacción.
2.  Tras el pago exitoso, la Cloud Function genera un `codigoVerificacion` único para cada asiento/documento de la colección `reservas`.
3.  La pantalla `ResumenReservasSesionView` lista las reservas del usuario del día de hoy, mostrando cada asiento en una tarjeta independiente con su código.
4.  **Falla detectada:** No existe un "Código Encuentro" legible para el humano. El `reservaGroupId` es un ID de sistema largo. El usuario no tiene un código único que represente a todo el grupo para mostrárselo al conductor.
5.  **Falla detectada:** La validación en la app del conductor es individual por asiento. No hay una función para "Validar Grupo Completo".

## 4. Comportamiento Esperado
1.  Al realizar una reserva grupal (>1 asiento), el sistema debe generar un **Código Encuentro** corto y legible (ej. 5 caracteres) que vincule a todos los pasajeros del grupo.
2.  Al finalizar el pago, el pasajero debe ver el **Código Encuentro** del grupo y, debajo, el listado de **Códigos Foto** (individuales) de cada pasajero.
3.  El conductor debe poder ingresar el **Código Encuentro** para marcar a todo el grupo como "Abordado" en un solo paso, o seguir validando uno a uno si lo prefiere.

## 5. Causa Raíz
La arquitectura actual utiliza el `reservaGroupId` únicamente como un puntero técnico para la base de datos y el webhook de pago, pero no lo trata como una entidad de negocio visible para el usuario. 
*   En `functions/index.js`, el `reservaGroupId` se deriva de `db.collection("reservas").doc().id`, resultando en un string alfanumérico largo y poco práctico para dictar.
*   En la UI de Flutter, se prioriza la visualización de la reserva individual, perdiendo el contexto de "grupo" una vez que el pago es procesado.

## 6. Solución Propuesta (Pasos Concretos)

### Fase A: Backend (Cloud Functions) - ✅ COMPLETADO
1.  Modificar `bloquearYCrearPreferencia` en `functions/index.js` para generar un `codigoEncuentro` corto:
    ```javascript
    const codigoEncuentro = Math.random().toString(36).substring(2, 7).toUpperCase();
    ```
2.  Almacenar este `codigoEncuentro` en cada documento de la reserva creada dentro del loop.
    *   *Nota: También se implementó en `crearPreferenciaPago` para mantener la consistencia en reservas individuales.*

### Fase B: Frontend Pasajero - ✅ COMPLETADO
1.  Actualizar `ResumenReservasSesionView` para agrupar visualmente las tarjetas que compartan el mismo `codigoEncuentro`.
2.  Mostrar el `codigoEncuentro` en grande en la parte superior del grupo.

### Fase C: Frontend Conductor - ✅ COMPLETADO
1.  En `PassengersTab`, agregar un botón "VALIDAR GRUPO" cuando se detecte un agrupamiento por `reservaGroupId`.
2.  Implementar en `TripService` una función `abordarGrupo(viajeId, codigoEncuentro)` que actualice masivamente el estado a 'abordado'.
3.  Implementar diálogo en `DriverTripView` para capturar el código y procesar la validación masiva.

## 7. Riesgos y Casos Borde
*   **Reservas Parciales:** Si un grupo reserva 8 asientos pero solo llegan 6 personas, el conductor debe tener la opción de desmarcar individuos antes de validar el grupo o seguir usando la validación individual.
*   **Pagos Sucesivos:** Si un usuario hace dos pagos separados para el mismo viaje, actualmente tendrían dos `codigoEncuentro` distintos. Se debe decidir si se desea unificar bajo un solo código de usuario para el viaje.
*   **Concurrencia:** Asegurar que la validación masiva use una transacción para evitar inconsistencias en el conteo de asientos del viaje.

---
**Análisis realizado por:** Ingeniero de Software SICOL
**Fecha:** 07/07/2026
