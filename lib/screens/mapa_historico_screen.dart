import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/punto_gps.dart';
import '../models/recorrido.dart';
import '../services/db_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class MapaHistoricoScreen extends StatefulWidget {
  const MapaHistoricoScreen({super.key});

  @override
  State<MapaHistoricoScreen> createState() => _MapaHistoricoScreenState();
}

class _MapaHistoricoScreenState extends State<MapaHistoricoScreen> {
  final DbService _dbService = DbService();
  final MapController _mapController = MapController();

  DateTime _fechaDesde = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaHasta = DateTime.now();

  List<Recorrido> _recorridos = [];
  Map<int, List<PuntoGps>> _puntosPorRecorrido = {};
  bool _cargando = false;
  bool _hayDatos = false;

  static final List<Color> _colores = [
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
      final puntosMap = <int, List<PuntoGps>>{};

      for (final recorrido in _recorridos) {
        if (recorrido.id != null) {
          final puntos = await _dbService.getPuntosByRecorridoId(recorrido.id!);
          puntosMap[recorrido.id!] = puntos;
        }
      }

      setState(() {
        _recorridos = recorridos;
        _puntosPorRecorrido = puntosMap;
        _cargando = false;
        _hayDatos = _recorridos.isNotEmpty;
      });
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatFecha(DateTime fecha) =>
      '${fecha.day}/${fecha.month}/${fecha.year}';

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
    final colores = ThemeService.currentTheme;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mapa Historico'), centerTitle: true),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: _FechaBoton(
                      fecha: _fechaDesde,
                      onTap: _seleccionarFechaDesde,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('a'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FechaBoton(
                      fecha: _fechaHasta,
                      onTap: _seleccionarFechaHasta,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _cargarRecorridos,
                    child: const Text('Mostrar'),
                  ),
                ],
              ),
            ),
            if (_cargando)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (!_hayDatos)
              const Expanded(child: Center(child: Text('Sin datos')))
            else
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(-0.2, -78.5),
                        initialZoom: 10,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.david.georuta',
                        ),
                        PolylineLayer(polylines: _generarPolylines()),
                        MarkerLayer(markers: _generarMarkers()),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_recorridos.length} recorrido(s)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            ..._recorridos.asMap().entries.map(
                              (e) => _LeyendaItem(
                                index: e.key,
                                nombre: e.value.nombre,
                              ),
                            ),
                          ],
                        ),
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

  List<Polyline> _generarPolylines() {
    final polylines = <Polyline>[];
    for (int i = 0; i < _recorridos.length; i++) {
      final recorrido = _recorridos[i];
      if (recorrido.id == null) continue;
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
      if (recorrido.id == null) continue;
      final puntos = _puntosPorRecorrido[recorrido.id];
      if (puntos == null || puntos.isEmpty) continue;
      markers.add(
        Marker(
          point: LatLng(puntos.first.latitud, puntos.first.longitud),
          width: 30,
          height: 30,
          child: Icon(
            Icons.flag,
            color: _colores[i % _colores.length],
            size: 30,
          ),
        ),
      );
      markers.add(
        Marker(
          point: LatLng(puntos.last.latitud, puntos.last.longitud),
          width: 30,
          height: 30,
          child: Icon(
            Icons.location_pin,
            color: _colores[i % _colores.length],
            size: 30,
          ),
        ),
      );
    }
    return markers;
  }
}

class _FechaBoton extends StatelessWidget {
  final DateTime fecha;
  final VoidCallback onTap;
  const _FechaBoton({required this.fecha, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text('${fecha.day}/${fecha.month}/${fecha.year}'),
          ],
        ),
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final int index;
  final String nombre;
  const _LeyendaItem({required this.index, required this.nombre});

  static final _colores = [
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
  Widget build(BuildContext context) {
    final color = _colores[index % _colores.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              nombre.length > 15 ? '${nombre.substring(0, 15)}...' : nombre,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
