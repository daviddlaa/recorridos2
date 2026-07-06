import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/punto_gps.dart';
import '../models/recorrido.dart';
import '../services/caching_tile_provider.dart';
import '../services/db_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/map_data_usage_badge.dart';

class MapaHistoricoScreen extends StatefulWidget {
  const MapaHistoricoScreen({super.key});

  @override
  State<MapaHistoricoScreen> createState() => _MapaHistoricoScreenState();
}

class _MapaHistoricoScreenState extends State<MapaHistoricoScreen> {
  final DbService _dbService = DbService();
  final MapController _mapController = MapController();
  final CachingTileProvider _tileProvider = CachingTileProvider();

  DateTime _fechaDesde = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaHasta = DateTime.now();

  List<Recorrido> _recorridos = [];
  Map<int, List<PuntoGps>> _puntosPorRecorrido = {};
  final Set<int> _ocultos = {}; // IDs de recorridos ocultos en el mapa
  bool _cargando = false;
  bool _hayDatos = false;

  // Bottom sheet state
  bool _panelAbierto = false;

  static const List<Color> _colores = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _cargarRecorridos();
  }

  Future<void> _cargarRecorridos() async {
    setState(() => _cargando = true);

    try {
      final recorridos = await _dbService.getRecorridosByFechaRango(
        _fechaDesde,
        _fechaHasta,
      );

      final ids = recorridos
          .map((r) => r.id)
          .whereType<int>()
          .toList();

      // Carga batch: UNA consulta para TODOS los puntos
      final puntosMap = ids.isNotEmpty
          ? await _dbService.getPuntosByRecorridoIds(ids)
          : <int, List<PuntoGps>>{};

      if (!mounted) return;

      setState(() {
        _recorridos = recorridos;
        _puntosPorRecorrido = puntosMap;
        _ocultos.clear();
        _cargando = false;
        _hayDatos = _recorridos.isNotEmpty;
      });

      // Auto-zoom a los recorridos después de que el mapa se pinte
      if (_hayDatos) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ajustarZoom());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Ajusta el zoom para que todas las rutas visibles quepan en pantalla
  void _ajustarZoom() {
    final todosLosPuntos = <LatLng>[];
    for (int i = 0; i < _recorridos.length; i++) {
      if (_ocultos.contains(_recorridos[i].id)) continue;
      final puntos = _puntosPorRecorrido[_recorridos[i].id];
      if (puntos == null || puntos.length < 2) continue;
      todosLosPuntos.addAll(
        puntos.map((p) => LatLng(p.latitud, p.longitud)),
      );
    }

    if (todosLosPuntos.length < 2) return;

    try {
      final bounds = LatLngBounds.fromPoints(todosLosPuntos);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {
      // Si hay error (ej. todos los puntos iguales), ignorar
    }
  }

  void _toggleOculto(int? recorridoId) {
    if (recorridoId == null) return;
    setState(() {
      if (_ocultos.contains(recorridoId)) {
        _ocultos.remove(recorridoId);
      } else {
        _ocultos.add(recorridoId);
      }
    });
  }

  void _aplicarFechaRapida(String periodo) {
    final ahora = DateTime.now();
    switch (periodo) {
      case 'hoy':
        _fechaDesde = ahora;
        _fechaHasta = ahora;
      case 'semana':
        _fechaDesde = ahora.subtract(const Duration(days: 7));
        _fechaHasta = ahora;
      case 'semana_pasada':
        _fechaDesde = ahora.subtract(const Duration(days: 14));
        _fechaHasta = ahora.subtract(const Duration(days: 7));
      case 'mes':
        _fechaDesde = ahora.subtract(const Duration(days: 30));
        _fechaHasta = ahora;
    }
    _cargarRecorridos();
  }

  Future<void> _seleccionarFechaDesde() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaDesde,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _fechaDesde = fecha);
  }

  Future<void> _seleccionarFechaHasta() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _fechaHasta = fecha);
  }



  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.getThemeData(
      ThemeService.currentTheme,
      ThemeService.isDarkMode,
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial de rutas'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // --- Selector de fechas compacto ---
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                children: [
                  // Selector de rango
                  Row(
                    children: [
                      Expanded(
                        child: _FechaBoton(
                          fecha: _fechaDesde,
                          label: 'Desde',
                          onTap: _seleccionarFechaDesde,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      Expanded(
                        child: _FechaBoton(
                          fecha: _fechaHasta,
                          label: 'Hasta',
                          onTap: _seleccionarFechaHasta,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _cargarRecorridos,
                          child: const Text('Ir'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Chips de fecha rápida
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ChipRapido(
                          icon: Icons.today,
                          label: 'Hoy',
                          onTap: () => _aplicarFechaRapida('hoy'),
                        ),
                        const SizedBox(width: 6),
                        _ChipRapido(
                          icon: Icons.date_range,
                          label: '7 días',
                          onTap: () => _aplicarFechaRapida('semana'),
                          activo: true,
                        ),
                        const SizedBox(width: 6),
                        _ChipRapido(
                          icon: Icons.arrow_back,
                          label: 'Semana pasada',
                          onTap: () => _aplicarFechaRapida('semana_pasada'),
                        ),
                        const SizedBox(width: 6),
                        _ChipRapido(
                          icon: Icons.calendar_month,
                          label: '30 días',
                          onTap: () => _aplicarFechaRapida('mes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- Mapa + panel ---
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : !_hayDatos
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Sin recorridos en este período'),
                            ],
                          ),
                        )
                      : Stack(
                          children: [
                            // Mapa
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: const LatLng(-0.2, -78.5),
                                initialZoom: 10,
                                onTap: (_, __) {
                                  if (_panelAbierto) {
                                    setState(() => _panelAbierto = false);
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.david.georuta',
                                  tileProvider: _tileProvider,
                                ),
                                PolylineLayer(
                                  polylines: _generarPolylines(),
                                ),
                                MarkerLayer(
                                  markers: _generarMarkers(),
                                ),
                              ],
                            ),

                            // Badge de consumo de datos (esquina superior izquierda)
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: MapDataUsageBadge(),
                            ),

                            // Botón para abrir panel de lista
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: FloatingActionButton.small(
                                heroTag: 'lista_recorridos',
                                onPressed: () =>
                                    setState(() => _panelAbierto = !_panelAbierto),
                                child: Icon(
                                  _panelAbierto
                                      ? Icons.close
                                      : Icons.list,
                                ),
                              ),
                            ),

                            // Panel deslizable de lista de recorridos
                            if (_panelAbierto)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height:
                                    MediaQuery.of(context).size.height * 0.45,
                                child: _PanelRecorridos(
                                  recorridos: _recorridos,
                                  puntosPorRecorrido: _puntosPorRecorrido,
                                  ocultos: _ocultos,
                                  colores: _colores,
                                  onToggle: _toggleOculto,
                                  onCerrar: () =>
                                      setState(() => _panelAbierto = false),
                                  onZoom: _ajustarZoom,
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Generación de polylines (solo recorridos no ocultos) ---

  List<Polyline> _generarPolylines() {
    final polylines = <Polyline>[];
    for (int i = 0; i < _recorridos.length; i++) {
      final recorrido = _recorridos[i];
      if (recorrido.id == null || _ocultos.contains(recorrido.id)) continue;
      final puntos = _puntosPorRecorrido[recorrido.id];
      if (puntos == null || puntos.length < 2) continue;
      polylines.add(
        Polyline(
          points: puntos.map((p) => LatLng(p.latitud, p.longitud)).toList(),
          strokeWidth: 4,
          color: _colores[i % _colores.length],
        ),
      );
    }
    return polylines;
  }

  List<Marker> _generarMarkers() {
    final markers = <Marker>[];
    for (int i = 0; i < _recorridos.length; i++) {
      final recorrido = _recorridos[i];
      if (recorrido.id == null || _ocultos.contains(recorrido.id)) continue;
      final puntos = _puntosPorRecorrido[recorrido.id];
      if (puntos == null || puntos.isEmpty) continue;
      final color = _colores[i % _colores.length];
      markers.add(
        Marker(
          point: LatLng(puntos.first.latitud, puntos.first.longitud),
          width: 28,
          height: 28,
          child: Icon(Icons.flag, color: color, size: 28),
        ),
      );
      markers.add(
        Marker(
          point: LatLng(puntos.last.latitud, puntos.last.longitud),
          width: 28,
          height: 28,
          child: Icon(Icons.location_pin, color: color, size: 28),
        ),
      );
    }
    return markers;
  }
}

// ====================== WIDGETS AUXILIARES ======================

/// Botón para seleccionar fecha
class _FechaBoton extends StatelessWidget {
  final DateTime fecha;
  final String label;
  final VoidCallback onTap;
  const _FechaBoton({
    required this.fecha,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                Text(
                  '${fecha.day}/${fecha.month}/${fecha.year}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de fecha rápida
class _ChipRapido extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool activo;

  const _ChipRapido({
    required this.icon,
    required this.label,
    required this.onTap,
    this.activo = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: activo ? theme.colorScheme.primary.withAlpha(30) : null,
      side: activo
          ? BorderSide(color: theme.colorScheme.primary)
          : null,
    );
  }
}

/// Panel inferior con la lista de recorridos
class _PanelRecorridos extends StatelessWidget {
  final List<Recorrido> recorridos;
  final Map<int, List<PuntoGps>> puntosPorRecorrido;
  final Set<int> ocultos;
  final List<Color> colores;
  final Function(int?) onToggle;
  final VoidCallback onCerrar;
  final VoidCallback onZoom;

  const _PanelRecorridos({
    required this.recorridos,
    required this.puntosPorRecorrido,
    required this.ocultos,
    required this.colores,
    required this.onToggle,
    required this.onCerrar,
    required this.onZoom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPuntos = puntosPorRecorrido.values.fold<int>(
      0,
      (sum, pts) => sum + pts.length,
    );

    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle + header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  // Handle visual
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${recorridos.length} recorrido(s) — $totalPuntos pts',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    tooltip: 'Ajustar zoom',
                    onPressed: onZoom,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onCerrar,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Lista scrolleable
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: recorridos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = recorridos[i];
                  final puntos = puntosPorRecorrido[r.id] ?? [];
                  final oculto = r.id != null && ocultos.contains(r.id);
                  final color = colores[i % colores.length];

                  return _ItemRecorrido(
                    nombre: r.nombre,
                    fecha: r.fecha,
                    color: color,
                    oculto: oculto,
                    cantidadPuntos: puntos.length,
                    onToggle: () => onToggle(r.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de un recorrido en la lista
class _ItemRecorrido extends StatelessWidget {
  final String nombre;
  final DateTime fecha;
  final Color color;
  final bool oculto;
  final int cantidadPuntos;
  final VoidCallback onToggle;

  const _ItemRecorrido({
    required this.nombre,
    required this.fecha,
    required this.color,
    required this.oculto,
    required this.cantidadPuntos,
    required this.onToggle,
  });

  String _formatearFecha(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatearHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: oculto ? 0.4 : 1.0,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: oculto ? Colors.grey : color,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatearFecha(fecha)}  •  ${_formatearHora(fecha)} h  •  $cantidadPuntos pts',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: IconButton(
          icon: Icon(
            oculto ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: oculto ? Colors.grey : color,
          ),
          tooltip: oculto ? 'Mostrar ruta' : 'Ocultar ruta',
          onPressed: onToggle,
        ),
        onTap: onToggle,
      ),
    );
  }
}
