import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/punto_gps.dart';
import '../models/recorrido.dart';
import '../services/counting_tile_provider.dart';
import '../services/db_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/map_data_usage_badge.dart';

class RecorridoScreen extends StatefulWidget {
  final Recorrido recorrido;

  const RecorridoScreen({super.key, required this.recorrido});

  @override
  State<RecorridoScreen> createState() => _RecorridoScreenState();
}

class _RecorridoScreenState extends State<RecorridoScreen> {
  final DbService _dbService = DbService();
  final MapController _mapController = MapController();
  final CountingTileProvider _tileProvider = CountingTileProvider();

  List<PuntoGps> _puntos = [];
  bool _cargando = true;

  AppColors get _coloresActuales => ThemeService.currentTheme;

  @override
  void initState() {
    super.initState();
    _cargarPuntos();
  }

  @override
  void dispose() {
    _tileProvider.dispose();
    super.dispose();
  }

  Future<void> _cargarPuntos() async {
    if (widget.recorrido.id == null) return;

    try {
      final puntos = await _dbService.getPuntosByRecorridoId(
        widget.recorrido.id!,
      );
      setState(() {
        _puntos = puntos;
        _cargando = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.getThemeData(
      _coloresActuales,
      ThemeService.isDarkMode,
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.recorrido.nombre), centerTitle: true),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _puntos.isEmpty
            ? const Center(child: Text('Sin puntos'))
            : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _puntos.first.latitud,
                        _puntos.first.longitud,
                      ),
                      initialZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.david.georuta',
                        tileProvider: _tileProvider,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _puntos.first.latitud,
                              _puntos.first.longitud,
                            ),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.flag,
                              color: _coloresActuales.secondary,
                              size: 40,
                            ),
                          ),
                          Marker(
                            point: LatLng(
                              _puntos.last.latitud,
                              _puntos.last.longitud,
                            ),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_pin,
                              color: _coloresActuales.primary,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                      if (_puntos.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _puntos
                                  .map((p) => LatLng(p.latitud, p.longitud))
                                  .toList(),
                              strokeWidth: 5,
                              color: _coloresActuales.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Positioned(
                    top: 12,
                    left: 12,
                    child: MapDataUsageBadge(),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_puntos.isNotEmpty) {
              _mapController.move(
                LatLng(_puntos.first.latitud, _puntos.first.longitud),
                18,
              );
            }
          },
          child: Icon(Icons.my_location, color: _coloresActuales.primary),
        ),
      ),
    );
  }
}
