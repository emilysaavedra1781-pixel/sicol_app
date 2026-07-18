# Análisis y Propuesta: Sistema de Multi-Reserva (SICOL)

Este documento detalla el funcionamiento actual del sistema de reservas y la propuesta técnica para permitir que un pasajero reserve hasta 4 asientos en una sola operación, incluyendo datos de acompañantes.

## 1. Funcionamiento de la Reserva Actual

### Código de Creación
La lógica reside principalmente en la Cloud Function `bloquearYCrearPreferencia` (`functions/index.js`) y es disparada desde el widget `SeatSelectionView` (`lib/features/passenger/seat_selection_view.dart`).

**Proceso actual:**
1. El usuario selecciona asientos en la interfaz.
2. Se abre un formulario modal que ya solicita Nombre y DNI por cada asiento seleccionado.
3. Se invoca la función de backend que ejecuta una **Transacción de Firestore** para:
   - Verificar la disponibilidad de cada asiento.
   - Cambiar el estado de los asientos a `bloqueado` en el documento del viaje.
   - Crear un documento independiente en la colección `reservas` por cada asiento.
   - Generar un `reservaGroupId` que vincula todas las reservas de esa transacción para el pago.

```javascript
// Fragmento de la transacción en functions/index.js (Líneas 50-80 aprox)
const bloqueadoExitoso = await db.runTransaction(async (tx) => {
    // ... validación de asientos ...
    for (const numAsiento of asientos) {
        const key = `asiento_${numAsiento}`;
        asientosMapa[key] = {
            numero: numAsiento,
            estado: 'bloqueado',
            bloqueado_por: pasajeroId,
            bloqueado_at: now
        };
    }
    tx.update(vRef, { asientos: asientosMapa });
    return true;
});
```

### Estructura del Documento de Reserva
Cada asiento reservado genera un documento con los siguientes campos:

| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `viajeId` | String | ID del viaje asociado. |
| `pasajeroUid` | String | UID del usuario que realiza la compra. |
| `nombreViajero` | String | Nombre de la persona que ocupará el asiento. |
| `dniViajero` | String | DNI de la persona que ocupará el asiento. |
| `numeroAsiento` | Number | Número del asiento físico. |
| `paradero` | String | Punto de recojo seleccionado. |
| `estado` | String | `bloqueada`, `confirmada`, `abordado`, etc. |
| `monto` | Number | Costo del pasaje (S/ 15.00). |
| `reservaGroupId` | String | ID para agrupar múltiples asientos en un solo pago. |
| `codigoVerificacion` | String | Código de 5 dígitos para el conductor (post-pago). |

## 2. Propuesta de Nuevo Flujo Multi-Reserva

Aunque el código actual ya tiene cimientos para multi-asiento, se requiere optimizar la experiencia y la validación de límites.

### Flujo de Usuario
1. **Selección**: El pasajero marca hasta 4 asientos en el mapa del bus.
2. **Validación de Límite**: Si intenta marcar un 5to, la app muestra un aviso: "Máximo 4 asientos por reserva".
3. **Datos de Acompañantes**: El formulario modal se precarga con los datos del usuario logueado para el primer asiento, y solicita obligatoriamente Nombre y DNI para los asientos 2, 3 y 4.
4. **Transacción Única**: Se envía todo el paquete al backend. Si el sistema detecta que un solo asiento del grupo fue tomado por otro usuario mientras el pasajero llenaba los datos, se cancela todo el bloque y se pide re-seleccionar.

## 3. Propuesta de Estructura de Datos

Se recomienda mantener la **estructura de documentos independientes** (un documento por asiento) pero agregando campos de jerarquía para mejor gestión:

**Nuevos campos sugeridos:**
- `esTitular`: Boolean (true si es la persona que pagó).
- `acompananteDe`: String (UID del titular, para auditoría rápida).
- `totalGrupo`: Number (cantidad de personas en esa reserva grupal).

## 4. Impacto en el Sistema

### Contador de Asientos
El sistema actual ya maneja correctamente la actualización atómica de `asientosOcupados`. Al ser una sola transacción, el contador se incrementará en N (1-4) de forma segura sin riesgo de sobre-venta.

### Vista del Conductor
El conductor seguirá viendo una lista plana de pasajeros en su pestaña de "Pasajeros". 
*   **Mejora sugerida**: Agrupar visualmente a los pasajeros que tengan el mismo `reservaGroupId` para que el conductor sepa que vienen juntos.

### Pago con MercadoPago
El backend ya multiplica `cantidad * precio_unitario`. El impacto es nulo en la integración, pero se debe asegurar que el `external_reference` del pago contenga el `reservaGroupId` para confirmar todos los documentos de una vez al recibir el webhook.

## 5. Pasos de Implementación (Prioridad)

1.  **Frontend (UI)**: Limitar la selección en `SeatSelectionView` a máximo 4 elementos.
2.  **Frontend (UX)**: Precargar datos del perfil del usuario en el primer formulario de viajero.
3.  **Backend (Functions)**: Validar en `bloquearYCrearPreferencia` que el array de asientos no exceda los 4 elementos (Seguridad).
4.  **Backend (Webhooks)**: Asegurar que `registrarMultiReservaExitosa` envíe notificaciones push tanto al titular como al conductor detallando el grupo completo.
5.  **Admin Panel**: Actualizar el dashboard para que el conteo de "Ingresos de Hoy" sume correctamente todas las reservas del grupo.
