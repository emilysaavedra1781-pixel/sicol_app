# Diagnóstico: ¿Por qué no se ven los colectivos disponibles?

Este documento detalla la investigación técnica sobre por qué los pasajeros no pueden visualizar los colectivos activos en la aplicación.

## 1. Análisis de la Consulta a Firestore
La consulta se realiza en el archivo `lib/features/passenger/buscar_tab.dart`, dentro del método `_buildListaColectivos()`.

### Código de la Query:
```dart
// Query 1: Viajes con ruta específica
_db.collection('viajes')
   .where('estado', isEqualTo: 'activo')
   .where('ruta', isEqualTo: _rutaSeleccionada)
   .snapshots()

// Query 2: Viajes sin ruta asignada (iniciados fuera de rango)
_db.collection('viajes')
   .where('estado', isEqualTo: 'activo')
   .where('ruta', isNull: true)
   .snapshots()
```

### Problemas detectados en la consulta:
1.  **Falta de Manejo de Errores (Spinner Infinito):** El widget utiliza dos `StreamBuilder` anidados. Si alguna de las consultas falla (por ejemplo, por un **índice compuesto faltante**), el `snapshot.hasError` será true y `snapshot.hasData` será false. El código actual solo verifica `!snapshot.hasData`, lo que resulta en un indicador de carga (`CircularProgressIndicator`) infinito.
2.  **Índices Compuestos:** Firestore requiere un índice compuesto para consultas que filtran por dos campos (ej. `estado == 'activo'` AND `ruta == 'chosica_lima'`). Si este índice no se ha creado manualmente en la consola de Firebase, la consulta fallará silenciosamente en la UI.

## 2. Modelo de Datos en Firestore
Para que un colectivo aparezca en la lista del pasajero, el documento en la colección `viajes` debe cumplir con:

| Campo | Valor Requerido | Estado |
| :--- | :--- | :--- |
| `estado` | `'activo'` | **Crítico**: Si el conductor ya presionó "Arrancar", el estado cambia a `'en_camino'` y desaparece de la búsqueda. |
| `ruta` | `_rutaSeleccionada` o `null` | Si el valor en Firestore no coincide exactamente con el ID de ruta del frontend (ej: `chosica_lima`), no se mostrará. |
| `asientosOcupados` | `< capacidad` | Aunque el filtro es por estado, el botón de reserva se deshabilita si está lleno. |

## 3. Barrera de Interfaz de Usuario (UX)
Un problema fundamental detectado es la condición de renderizado en `buscar_tab.dart`:

```dart
if (_rutaSeleccionada != null && _paraderoSeleccionado != null)
    _buildListaColectivos(),
```

**Consecuencia:** Si el pasajero selecciona la ruta (ej: Chosica -> Lima) pero **no selecciona un paradero** específico (ya sea de la lista de frecuentes o por buscador), la lista de colectivos **ni siquiera se intenta cargar**. El pasajero ve una pantalla vacía debajo del selector, lo que parece un error de carga.

## 4. Reglas de Seguridad
Revisando `firestore.rules`:
```javascript
match /viajes/{viajeId} {
  allow read: if request.auth != null;
}
```
Las reglas son correctas; cualquier usuario autenticado puede leer los viajes. No es un problema de permisos.

## 5. Conclusión y Solución Sugerida

### Prioridad 1: Eliminar el Spinner Infinito
Se debe agregar un bloque de manejo de errores en `buscar_tab.dart` para ver el error real de Firestore (probablemente el link para crear el índice).

### Prioridad 2: Flexibilidad en la UI
Permitir que `_buildListaColectivos()` se ejecute solo con la ruta seleccionada, sin obligar al paradero inmediatamente, o mostrar un mensaje claro: "Selecciona un paradero para ver colectivos".

### Prioridad 3: Verificar Estados en Firestore
Asegurarse de que los documentos en la colección `viajes` tengan el campo `estado: 'activo'`. Si están en otro estado, no serán visibles por diseño.

---
**Cambio de código recomendado en `buscar_tab.dart`:**
```dart
// En el builder de StreamBuilder
if (snapshot.hasError) {
  return Center(child: Text('Error: ${snapshot.error}')); // Esto revelará el link del índice
}
```
