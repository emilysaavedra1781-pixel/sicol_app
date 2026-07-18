# Análisis de Flujo de Vehículos (SICOL)

Este documento detalla el estado actual del registro y gestión de vehículos, y propone un flujo optimizado para la administración.

## 1. Estado Actual

### ¿Cómo funciona el registro de vehículo actualmente?
Actualmente, el registro de vehículos está **desacoplado** entre el conductor y el administrador:
1.  **Conductor**: Durante el registro inicial (`AuthService.registerConductor`), los datos del vehículo se guardan **dentro del documento del conductor** en la colección `usuarios`, bajo un campo mapa llamado `vehiculo`.
2.  **Administrador**: Existe una pestaña de "Vehículos" (`VehiculosTab`) que gestiona una colección independiente llamada `vehiculos`. Esta colección se usa para registros manuales del administrador y no está vinculada automáticamente al registro del conductor.

### ¿Existe una tabla o lista de vehículos en el panel admin?
Sí, en `lib/features/admin/tabs/vehiculos_tab.dart`. Sin embargo, esta vista **solo muestra los documentos de la colección `vehiculos`**, ignorando por completo los vehículos registrados por los conductores en la colección `usuarios`.

### ¿Cómo está relacionado el vehículo con el conductor?
En el modelo actual, la relación es **embebida**:
*   El conductor "posee" sus datos de vehículo dentro de su propio documento.
*   **No existe un vínculo** en la colección `vehiculos` hacia el conductor (UID).
*   **No hay validación cruzada**: Un conductor puede registrar una placa que el admin ya registró manualmente en la otra colección.

### Campos actuales del documento del vehículo (en `usuarios`):
*   `placa` (String)
*   `capacidad` (String/Number)
*   `modelo` (String)
*   `marca` (String)
*   `color` (String)
*   `fotoVehiculoUrl` (String - URL de Firebase Storage)

---

## 2. Propuesta de Flujo: Registro y Aprobación Centralizada

El objetivo es que el vehículo sea una entidad con ciclo de vida propio, validada por el Administrador.

### Flujo Propuesto:
1.  **Registro**: El conductor se registra. Los datos del vehículo se guardan en la colección `usuarios` (como hasta ahora) pero con un nuevo campo `vehiculo.estado: "pendiente"`.
2.  **Vista Admin**: Se debe modificar `vehiculos_tab.dart` (o crear una nueva sección) que realice una consulta `where("rol", "==", "conductor")` sobre la colección `usuarios` para listar los vehículos que están en estado "pendiente".
3.  **Acción Admin**: El administrador podrá visualizar la placa, marca, modelo, color, capacidad y el nombre del conductor asociado. Al presionar "Aprobar", el campo `vehiculo.estado` cambia a `"aprobado"`.
4.  **Bloqueo de Operación**: En `driver_home_view.dart`, el botón "INICIAR VIAJE" debe estar deshabilitado si `vehiculo.estado != "aprobado"`.

---

## 3. Cambios Necesarios

### Firestore:
*   Añadir el campo `estado` dentro del mapa `vehiculo` en la colección `usuarios`.
*   Añadir el campo `fechaRegistroVehiculo` para ordenar las solicitudes.

### Flutter:
1.  **`AuthService.registerConductor`**: Inicializar `vehiculo.estado = "pendiente"`.
2.  **`VehiculosTab` (Admin)**: 
    *   Cambiar la fuente de datos: En lugar de leer de la colección `vehiculos`, leer de `usuarios` donde `rol == "conductor"`.
    *   Implementar botones de "Aprobar" y "Rechazar" que actualicen el subcampo del documento.
3.  **`DriverHomeView` (Conductor)**:
    *   Agregar una validación en el `StreamBuilder` principal. Si el vehículo está pendiente, mostrar un banner informativo: *"Tu vehículo está siendo revisado por un administrador"*.
    *   Bloquear el inicio de viaje.

### Cloud Functions:
*   **Opcional**: Crear un trigger `onUpdate` que notifique al conductor vía push cuando su vehículo sea aprobado.

---
**Archivo generado el 07/07/2026**
