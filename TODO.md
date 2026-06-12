# TODO - Agregar campo nombre al recorrido

## Pasos de implementación:

- [x] 1. Modificar home_screen.dart - agregar TextField para nombre en el diálogo
- [x] 2. Modificar map_widget.dart - agregar parámetro nombreRecorrido
- [x] 3. Testing

---

## Detalles:

### Paso 1: home_screen.dart
- Modificar `_mostrarDialogoDuracion()` para incluir TextField
- Agregar variable `_nombreRecorrido`
- Hacer validación obligatoria

### Paso 2: map_widget.dart
- Agregar parámetro `nombreRecorrido` al constructor
- Usar el nombre al guardar en BD
