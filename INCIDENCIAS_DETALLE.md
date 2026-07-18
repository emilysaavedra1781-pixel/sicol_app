# Módulo de Incidencias: Detalle Técnico (SICOL)

Este documento describe el funcionamiento, flujo y tipos de reportes en el módulo de incidencias del ecosistema SICOL.

---

### 1. Acceso del Conductor
El conductor puede acceder a la vista `ReportarIncidenciaView` desde dos puntos:

*   **Desde el Panel de Viaje (`TripTab` en `driver_trip_view.dart`)**:
    Aparece un botón de texto con ícono al final de la pestaña principal del viaje.
    ```dart
    if (enCamino) ...[
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportarIncidenciaView(
                  rolUsuario: 'conductor',
                  viajeId: viajeId,
                ),
              ),
            );
          },
          icon: const Icon(Icons.report_problem_outlined, size: 16),
          label: const Text('REPORTAR INCIDENCIA', ...),
        ),
      ),
    ```
*   **Desde el Menú Lateral (`DriverDrawer`)**:
    Existe la opción "REPORTAR INCIDENCIA". El sistema verifica si hay un viaje activo antes de permitir el acceso.

### 2. Estados Disponibles
La disponibilidad depende del punto de acceso:
*   **En la pestaña de viaje**: El botón solo es visible si el estado del viaje es `en_camino`.
*   **Desde el Drawer**: Está disponible siempre que el viaje tenga el estado `activo` (creado pero no arrancado) o `en_camino`.
*   **Finalizado**: No es posible reportar incidencias una vez que el viaje ha pasado a estado `finalizado`.

### 3. Tipos de Incidencias (Conductor)
El selector de tipo de problema muestra las siguientes opciones para el conductor:
1.  `Retraso` (Habilita el Slider de minutos).
2.  `Accidente`
3.  `Desvío de ruta`
4.  `Problema con pasajero`
5.  `Otro`

### 4. Flujo Post-Envío
Cuando el conductor (o pasajero) envía el reporte:
*   **Colección**: Se guarda en `incidencias` en Firestore.
*   **Campos del documento**:
    *   `usuarioId`: UID del emisor.
    *   `rolUsuario`: 'conductor' o 'pasajero'.
    *   `tipo`: El valor seleccionado en el dropdown.
    *   `descripcion`: Texto detallado del problema.
    *   `viajeId`: ID del viaje asociado (o 'GENERAL' si es pasajero sin viaje).
    *   `minutosRetraso`: (Opcional) Solo si el tipo es 'Retraso'.
    *   `estado`: Se inicializa en `'pendiente'`.
    *   `creadoEn`: Timestamp del servidor.
*   **Notificaciones**:
    *   **Pasajeros**: Reciben un push inmediatamente si el conductor reporta "Desvío de ruta" o "Retraso" (>= 5 min) a través de la Cloud Function `triggerNotificarIncidencia`.
    *   **Admin**: **❌ No se notifica automáticamente al admin**. El sistema actual solo notifica a los pasajeros para mitigar la incertidumbre en ruta. El administrador debe revisar la colección manualmente o desde su panel si tiene vista de historial.

### 5. Incidencias del Pasajero
**✅ Sí, el pasajero puede reportar incidencias**. Puede hacerlo desde su menú lateral o desde la pestaña de perfil.

**Tipos de Incidencias (Pasajero):**
1.  `Conductor no se presentó`
2.  `Vehículo en mal estado`
3.  `Comportamiento inapropiado`
4.  `Otro`

**Estado**: ✅ Implementada.
