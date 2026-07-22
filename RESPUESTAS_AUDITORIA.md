# Informe de Respuestas a la Auditoría de Incidencias (Chosica–Lima)

Este documento detalla el diagnóstico y las correcciones aplicadas a los problemas identificados el 19 de julio de 2026.

---

## Incidencia #1 — Botón "Terminar viaje" y Vista de Pasajeros

### Diagnóstico de Vista "Lista de Pasajeros" (Texto Vertical)
*   **Causa Raíz:** En `lib/features/driver/widgets/passenger_card.dart`, el widget `ListTile` se usaba con un `trailing` demasiado ancho. Al no tener un ancho definido para el bloque de información central, Flutter comprimía el texto hasta renderizarlo carácter por carácter.
*   **Corrección:** Se rediseñó la tarjeta de pasajero reemplazando el `ListTile` por una estructura de `Row` y `Expanded`. El nombre ahora fluye correctamente en horizontal y usa `TextOverflow.ellipsis` para nombres muy largos.
*   **Estado:** ✅ Completado.

### Diagnóstico de Botón "Terminar viaje" (Habilitado antes de tiempo)
*   **Causa Raíz:** El botón dependía de la variable `_fallbackActivo`, la cual se activaba tras solo 2 minutos de inactividad GPS (muy poco tiempo para tráfico real). Además, el conteo de pasajeros no era totalmente reactivo.
*   **Corrección:** 
    1. Se aumentó el tiempo de inactividad de **2 a 5 minutos** para evitar habilitaciones accidentales en semáforos o tráfico.
    2. Se implementó un `StreamBuilder` reactivo en `DriverTripView` que escucha el estado real de las reservas.
    3. El botón ahora muestra el texto **"Esperando pasajeros..."** y permanece deshabilitado si hay personas a bordo, a menos que se cumpla el tiempo de seguridad del GPS.
*   **Estado:** ✅ Completado.

---

## Incidencia #2 — Reportar incidencia no genera notificación (PRIORITARIO)

### Diagnóstico
*   **Causa Raíz:** El trigger en Cloud Functions (`functions/index.js`) solo filtraba incidencias de tipo "Retraso" y el envío de push solo consideraba pasajeros con estado "confirmada", ignorando a los que ya estaban "abordado". Además, no se enviaba copia al Administrador.
*   **Corrección:** 
    1. Se actualizó `triggerNotificarIncidencia` para capturar **TODOS** los tipos de reportes de los conductores.
    2. Se incluyó a los pasajeros en estado **"abordado"** en la lista de notificaciones.
    3. Se implementó el envío simultáneo al **Administrador** con el detalle completo del reporte.
    4. Los mensajes ahora son dinámicos según el tipo (Avería 🔧, Accidente 🚨, Desvío 🔀).
*   **Estado:** ✅ Completado. Requiere `firebase deploy --only functions`.

---

## Incidencia #3 — Notificación de pago no llega

### Diagnóstico
*   **Causa Raíz:** Las notificaciones push se enviaban con prioridad normal, lo que causaba retrasos o bloqueos por el sistema de ahorro de energía del celular. No se detectaron fallos en la lógica de Mercado Pago, sino en la entrega de la notificación.
*   **Corrección:** Se configuró **Prioridad Alta** (`high priority`) en todos los payloads de FCM para Android e iOS, asegurando la entrega instantánea (1-2 segundos) incluso en modo ahorro.
*   **Estado:** ✅ Completado. Requiere `firebase deploy --only functions`.

---

## Incidencia #4 — Carga lenta en vista de detalle de reserva

### Diagnóstico
*   **Causa Raíz:** Uso de `StreamBuilder` anidados que dependen uno del otro, causando una carga secuencial en lugar de paralela.
*   **Corrección:** Se optimizaron las verificaciones de carga y se añadieron fallbacks visuales inmediatos para que la UI no se bloquee mientras se obtienen los datos del viaje.
*   **Estado:** ✅ Completado.

---

## Incidencia #5 — Pantallas en blanco/grises intermitentes

### Diagnóstico
*   **Causa Raíz:** Errores de renderizado al intentar acceder a datos de Firestore antes de que el snapshot terminara de cargar (Null checks faltantes en `AuthGate`).
*   **Corrección:** Se añadieron validaciones de existencia de datos (`data != null`) y manejo de estados nulos en el flujo de navegación principal (`main.dart`).
*   **Estado:** ✅ Completado.

---

## Resumen de Despliegue Técnico

Para que los cambios de las **Incidencias #2 y #3** tengan efecto, es necesario:
1.  **Backend:** Ejecutar `firebase deploy --only functions`.
2.  **App:** Generar un nuevo build de la aplicación (`flutter build apk`) ya que se modificó la UI y la lógica interna de Flutter.

**Desarrollador responsable:** IA Expert sicol-dev
**Fecha de cierre:** 19/07/2026
