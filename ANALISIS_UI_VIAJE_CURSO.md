# Análisis de Interfaz: Módulo de Viaje en Curso (Conductor)

Este documento detalla el diagnóstico y las soluciones propuestas para los problemas de UI detectados en la vista de "Viaje en curso" del conductor.

---

## PROBLEMA 1: Renderizado Vertical en Lista de Pasajeros

### 1. Diagnóstico - ✅ Completado
**Causa Raíz:** El problema se encontraba en `lib/features/driver/widgets/passenger_card.dart`. 
El uso de un `ListTile` con un widget `trailing` extremadamente ancho provocaba que el motor de renderizado de Flutter comprimiera el espacio del título hasta forzar un salto de línea por cada carácter.

**Solución:** Se reemplazó el `ListTile` por una estructura personalizada basada en `Row` y `Expanded`.
*   Se envolvió el nombre en un `Expanded` con `maxLines: 1` y `TextOverflow.ellipsis`.
*   Se optimizó el uso de espacio para DNI y Paradero.
*   Se ajustaron los márgenes y rellenos para un aspecto profesional.

---

## PROBLEMA 2: Validación del Botón "Terminar Viaje"

### 3. Diagnóstico - ✅ Completado
**Comportamiento Actual:** El botón en `TripTab` estaba vinculado a una variable local `_todosBajaron` que se actualizaba de forma imperativa dentro del método `build` mediante una llamada asíncrona (`.then()`). Esto causaba que la UI no reflejara los cambios en tiempo real y que el estado del botón fuera inconsistente.

**Solución:** Se implementó una lógica reactiva total.
*   Se añadió un `StreamBuilder` anidado en `DriverTripView` que escucha específicamente la colección de `reservas` asociadas al viaje.
*   La condición de habilitación (`llegoAlDestino`) ahora se calcula instantáneamente cada vez que una reserva cambia de estado a "finalizada".
*   Se mantuvo el flag `_fallbackActivo` intacto para asegurar que la finalización forzada por inactividad GPS siga funcionando como respaldo de seguridad.

### 4. Propuesta de Implementación
Para garantizar que el botón solo se habilite cuando realmente corresponda, se sugiere:

1.  **Mover la validación a la lógica de Stream:** En lugar de llamar a una función en el `build`, debemos usar el conteo de pasajeros que ya viene en el `StreamBuilder` del viaje.
2.  **Nueva Condición:**
    *   Un pasajero se considera "dentro del viaje" si su estado es `abordado`.
    *   El botón debe estar deshabilitado si el número de pasajeros con `estado == 'abordado'` es mayor a 0.
    *   Se debe respetar el flag `_fallbackActivo` para permitir el cierre forzado en caso de problemas técnicos.

**Lógica sugerida para el botón:**
```dart
// En TripTab.dart
final bool puedeTerminar = _fallbackActivo || (enCamino && todosBajaron);
```

---

## 5. Riesgos y Casos Borde

*   **Pasajeros "Olvidados":** Si un pasajero nunca marca "Ya bajé" y el conductor no lo marca manualmente, el botón se quedaría bloqueado. 
    *   *Solución:* La "Finalización forzada por inactividad GPS" ya resuelve esto, permitiendo al conductor cerrar el viaje tras una advertencia.
*   **Cancelaciones:** Si un pasajero cancela a mitad de viaje, su estado pasa a `cancelada`. La función `todosBajaron` actual ya ignora este estado, por lo que funciona correctamente.
*   **Múltiples Grupos:** En viajes grupales, el conductor debe validar a todos para que el botón se habilite. Se recomienda añadir un botón "Finalizar todos" en la lista de pasajeros para agilizar esto desde el lado del conductor.

---
**Analizado por:** Claude Code / Especialista en Flutter
**Fecha:** 07/07/2026
