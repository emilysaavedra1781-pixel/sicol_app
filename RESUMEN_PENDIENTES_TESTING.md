# Resumen de Casos de Prueba Pendientes — Testing SICOL

Este documento detalla el estado actual de la cobertura de pruebas basada en el inventario oficial de casos de prueba (CPs).

## Estado General
- **Total de CPs Documentados**: 254
- **CPs Implementados**: 68
- **CPs Pendientes**: 186
- **Porcentaje de Avance**: 26.77%

---

## Desglose de CPs Pendientes por Bloque Lógico

| Bloque / Módulo | RFs Incluidos | CPs Pendientes | Prioridad |
| :--- | :--- | :--- | :--- |
| **1. Configuración (RF-NEW)** | RF-NEW (Parcial), RF52 | **9** | Alta |
| **4. Gestión Perfil Pasajero (RF04)** | RF04 | **4** | Media |
| **9. Reservas y Historial (RF10)** | RF10, RF12 | **5** | Media |
| **11. Comprobantes (RF13)** | RF13 | **2** | Media |
| **12. Seguimiento y ETA (RF14)** | RF14, RF19, RF27 | **6** | Alta |
| **13. Registro Conductor (RF53)** | RF53, RF16, RF26 | **10** | Crítica |
| **14. Login Conductor (RF23)** | RF23, RF46 | **8** | Alta |
| **15. Ejecución de Viaje (RF34)** | RF34, RF33, RF42 | **14** | Alta |
| **16. Gestión Pasajeros (RF15)** | RF15, RF51 | **12** | Alta |
| **17. Cierre de Viaje (RF18)** | RF18, RF44 | **8** | Alta |
| **18. Ingresos y Reportes (RF37)** | RF37, RF36 | **11** | Media |
| **19. Incidencias (RF49)** | RF49, RF32 | **16** | Alta |
| **20. Calificaciones (RF54)** | RF54, RF43 | **15** | Baja |
| **21. Notificaciones Push (RF30)** | RF30, RF39, RF35, RF31 | **16** | Alta |
| **22. Dashboard Admin (RF29)** | RF29, RF21 | **16** | Media |
| **23. Monitoreo y Flota (RF22)** | RF22, RF20, RF24, RF48 | **28** | Alta |

---

## Módulos Completados (100%)
- **RF01**: Registro de Usuario (5/5 CPs)
- **RF02**: Inicio de Sesión del Pasajero (5/5 CPs)
- **RF03**: Recuperación de Contraseña Pasajero (5/5 CPs)
- **RF05**: Selección de punto de recojo (4/4 CPs)
- **RF06**: Seleccionar Colectivo Disponible (4/4 CPs)
- **RF07+RF50**: Compra de Pasaje y Registro de Viajeros (4/4 CPs)
- **RF08**: Confirmación de Compra (4/4 CPs)
- **RF40**: Bloqueo Automático de Cuenta (4/4 CPs)

---

## Módulos Parciales
- **RF-NEW**: Configuración de Paraderos (3/11 CPs) - Deuda: UI Drag & Drop.
- **RF09**: Pago y División (3/4 CPs) - Deuda: Integración pasarela real.
- **RF13**: Registro y Gestión Conductor (9/19 CPs) - Deuda: UI Admin/FCM.
- **RF23+RF46**: Login y Recuperación Conductor (6/14 CPs) - Deuda: UI.
- **RF34+RF33+RF42**: Ejecución de Viaje (6/14 CPs) - Deuda: GPS/FCM.
- **RF11+RF28+RF41**: Cancelación y Reasignación (4/9 CPs) - Deuda: UI (Cambio de paradero).

---

## Próximos Pasos
1. Continuar con el bloque **RF14 — Seguimiento y ETA**.
2. Documentar fallos en el inventario para auditoría administrativa.
