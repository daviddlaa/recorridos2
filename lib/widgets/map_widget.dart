import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/punto_gps.dart';
import '../models/recorrido.dart';
import '../services/background_location_plugin.dart';
import '../services/caching_tile_provider.dart';
import '../services/logger_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/db_service.dart';
import 'map_data_usage_badge.dart';

class MapWidget extends StatefulWidget {
  final bool recorriendo;
  final String userId;
  final VoidCallback? onRecorridoGuardado;
  final LatLng? posicionInicial;
  final int? duracionMinutos;
  final String? nombreRecorrido;

  const MapWidget({
    super.key,
    required this.recorriendo,
    required this.userId,
    this.onRecorridoGuardado,
    this.posicionInicial,
    this.duracionMinutos,
    this.nombreRecorrido,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController mapController = MapController();
  final DbService _dbService = DbService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CachingTileProvider _tileProvider = CachingTileProvider();

  LatLng? posicionActual;
  StreamSubscription<Position>? subscription;
  final List<LatLng> recorrido = [];
  final List<DateTime> _fechasPuntos = [];

  bool _yaGuardo = false;

  // Control de posición inicial para el mapa
  LatLng? _centerInicial;

  // Broadcast receiver para ubicación en segundo plano
  static const _locationChannel = EventChannel(
    'io.flutter.plugins/location_events',
  );
  StreamSubscription? _bgLocationSubscription;

  // Timer para auto-stop
  Timer? _timerAutoStop;
  int _segundosRestantes = 0;

  // Tiempo real de inicio de grabación (para calcular correctamente aunque el timer se pause)
  DateTime? _inicioGrabacion;
  int _duracionTotalSegundos = 0;

  @override
  void initState() {
    super.initState();
    LoggerService().i('MapWidget initState');
    _centerInicial = widget.posicionInicial;
    _iniciarUbicacion();

    // INICIAR STREAM GPS SIEMPRE (desde el inicio, no solo al grabar)
    // Esto permite que la ubicación se actualice incluso cuando no está grabando
    _iniciarStreamGPS();

    _setupBackgroundLocationListener();

    // Centrar mapa en la primera ubicación conocida después de 1 segundo
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && posicionActual != null && _centerInicial == null) {
        _centerInicial = posicionActual;
        mapController.move(posicionActual!, 18);
      }
    });
  }

  void _setupBackgroundLocationListener() {
    _bgLocationSubscription = _locationChannel.receiveBroadcastStream().listen((
      dynamic event,
    ) {
      if (event == null) return;

      // Verificar si es un evento de control (time_expired, etc.)
      if (event is Map) {
        final map = Map<dynamic, dynamic>.from(event);
        if (map['type'] == 'time_expired') {
          LoggerService().i('Evento nativo: tiempo expirado!');
          if (mounted && widget.recorriendo) {
            _autoStopPorTiempo();
          }
          return;
        }
        // Si es evento de ubicación sin type (formato antiguo), seguir flujo normal
        if (map['type'] == null && map['latitude'] != null) {
          _procesarEventoBackground(event);
          return;
        }
      }

      // Formato antiguo: sin type, asumir ubicación
      _procesarEventoBackground(event);
    });
  }

  void _procesarEventoBackground(dynamic event) {
    if (!widget.recorriendo) return;

    LoggerService().d('Background GPS event: $event');
    final Map<dynamic, dynamic> locationData =
        event as Map<dynamic, dynamic>;
    final lat = locationData['latitude'] as double?;
    final lng = locationData['longitude'] as double?;
    final accuracy = locationData['accuracy'] as double? ?? 999.0;
    final provider = locationData['provider'] as String? ?? 'unknown';

    // Filter out very low-accuracy points (accuracy > 50m is unreliable)
    // Reducido de 100m a 50m para capturar más puntos en movimiento
    // En pocket mode el GPS puede tener accuracy > 50m pero sigue siendo útil
    if (accuracy > 50.0) {
      LoggerService().d(
        'Background GPS filtrado por baja precision: accuracy=$accuracy',
      );
      // IMPORTANTE:-Aún guardamos la posición aunque sea de baja precisión
      // Esto asegura que no perdamos puntos cuando el GPS tiene problemas
      if (lat != null && lng != null) {
        LoggerService().d('Background GPS (baja precision): $lat, $lng');
        _agregarPunto(lat, lng, accuracy: accuracy, provider: provider);
      }
      return;
    }

    if (lat != null && lng != null) {
      LoggerService().d('Background GPS: $lat, $lng (segundo plano)');
      _agregarPunto(lat, lng, accuracy: accuracy, provider: provider);
    }
  }

  /// Determina si un valor de accuracy es válido para comparación.
  /// accuracy=0.0 significa "desconocido/no disponible" (geolocator a veces reporta 0).
  /// Un accuracy válido de GPS real nunca es 0.0 exacto.
  bool _esAccuracyValido(double acc) => acc > 0.0;

  void _agregarPunto(
    double lat,
    double lng, {
    double accuracy = 0.0,
    String provider = 'unknown',
  }) {
    final ahora = DateTime.now();

    //Estrategia "mejor precisión gana" (versión corregida):
    //Si el proveedor es diferente y el nuevo punto tiene mejor accuracy,
    //reemplazamos el punto anterior en lugar de ignorarlo.
    //IMPORTANTE: accuracy=0.0 se ignora en la comparación (es valor inválido/desconocido).
    if (_ultimoPuntoTiempo != null) {
      final diferencia = ahora.difference(_ultimoPuntoTiempo!).inMilliseconds;

      //Si es muy reciente (menos de 300ms)
      if (diferencia < _minIntervaloMs) {
        //Solo procesamos si es un proveedor diferente
        if (provider != _ultimoProvider) {
          //Determinar accuracy REAL para comparación (ignorar 0.0)
          final accNuevoValida = _esAccuracyValido(accuracy);
          final accAnteriorValida = _esAccuracyValido(_ultimoAccuracy);

          if (accNuevoValida && accAnteriorValida) {
            //Ambos tienen accuracy válido: comparar (menor = mejor)
            if (accuracy < _ultimoAccuracy) {
              //Nuevo punto es mejor, reemplazar el anterior
              LoggerService().d(
                'Mejor precisión: $provider ($accuracy m) vs $_ultimoProvider ($_ultimoAccuracy m) - REEMPLAZANDO',
              );
              if (recorrido.isNotEmpty) {
                recorrido.removeLast();
                _fechasPuntos.removeLast();
              }
            } else {
              //Nuevo punto es peor, ignorar
              LoggerService().d(
                'Punto ignorado (menor precisión): $provider ($accuracy m) vs $_ultimoProvider ($_ultimoAccuracy m)',
              );
              setState(() {
                posicionActual = LatLng(lat, lng);
              });
              return;
            }
          } else if (accNuevoValida && !accAnteriorValida) {
            //Solo el nuevo tiene accuracy válido: el nuevo es mejor
            LoggerService().d(
              'Mejor precisión: $provider ($accuracy m) vs $_ultimoProvider (inválido) - REEMPLAZANDO',
            );
            if (recorrido.isNotEmpty) {
              recorrido.removeLast();
              _fechasPuntos.removeLast();
            }
          } else if (!accNuevoValida && accAnteriorValida) {
            //Solo el anterior tiene accuracy válido: el anterior es mejor
            LoggerService().d(
              'Punto ignorado (accuracy inválido): $provider ($accuracy m) vs $_ultimoProvider ($_ultimoAccuracy m)',
            );
            setState(() {
              posicionActual = LatLng(lat, lng);
            });
            return;
          } else {
            //Ninguno tiene accuracy válido: usar filtro de tiempo normal
            LoggerService().d(
              'Punto ignorado (ambos sin accuracy): $provider vs $_ultimoProvider - $diferencia ms',
            );
            setState(() {
              posicionActual = LatLng(lat, lng);
            });
            return;
          }
        } else {
          //Mismo proveedor, aplicar filtro de tiempo normal
          LoggerService().d('Punto ignorado (muy reciente): $diferencia ms');
          setState(() {
            posicionActual = LatLng(lat, lng);
          });
          return;
        }
      }
    }

    //Guardar punto
    _ultimoPuntoTiempo = ahora;
    _ultimoProvider = provider;
    _ultimoAccuracy = accuracy;

    LoggerService().d(
      'GPS: $lat, $lng (provider: $provider, accuracy: $accuracy)',
    );

    final nuevaPosicion = LatLng(lat, lng);
    setState(() {
      posicionActual = nuevaPosicion;
      if (widget.recorriendo) {
        recorrido.add(nuevaPosicion);
        _fechasPuntos.add(ahora);
      }
    });
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si iniciaron el recorrido
    if (!oldWidget.recorriendo && widget.recorriendo) {
      _iniciarGrabacionBackground();
    }
    // Si pasaron de recorriendo=true a false, guardamos el recorrido
    if (oldWidget.recorriendo && !widget.recorriendo) {
      _detenerGrabacionBackground();
      _guardarRecorrido();
    }
  }

  Future<void> _iniciarGrabacionBackground() async {
    LoggerService().i('Iniciandograbacion...');
    try {
      // IMPORTANTE: NO cancelamos el stream de foreground
      // Mantenemos ambos activos: servicio nativo + stream de foreground
      // Esto asegura que si uno falla (ej: teléfono bloqueado), el otro sigue funcionando

      // Resetear variables para nueva grabación
      _yaGuardo = false;
      recorrido.clear();
      _fechasPuntos.clear();
      _ultimoPuntoTiempo =
          null; // Resetear para permitir primer punto inmediato
      _ultimoProvider = '';
      _ultimoAccuracy = 999.0;

      // Guardar tiempo de inicio REAL (basado en reloj, no en ticks de timer)
      _inicioGrabacion = DateTime.now();

      // Iniciar timer si hay duración configurada
      if (widget.duracionMinutos != null && widget.duracionMinutos! > 0) {
        _duracionTotalSegundos = widget.duracionMinutos! * 60;
        _iniciarTimer();
      }

      // Verificar permisos primero
      await _verificarPermisos();

      // Iniciar servicio nativo en segundo plano CON DURACIÓN
      await _iniciarServicioNativo(
        true,
        duracionMinutos: widget.duracionMinutos ?? 0,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar grabación: $e')),
        );
      }
    }
  }

  void _iniciarTimer() {
    // Inicializar el valor ANTES del primer tick del timer
    // para que la UI muestre el contador inmediatamente
    _segundosRestantes = _duracionTotalSegundos;
    _timerAutoStop?.cancel();
    _timerAutoStop = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_inicioGrabacion == null) return;

      // Calcular tiempo restante REAL basado en el reloj,
      // NO en decrementos. Esto asegura que si el timer se pausa
      // (background, pantalla bloqueada), al reanudarse calcula
      // el tiempo correcto automáticamente.
      final elapsedMs = DateTime.now().difference(_inicioGrabacion!).inMilliseconds;
      final restantes = (_duracionTotalSegundos * 1000 - elapsedMs) ~/ 1000;

      if (restantes > 0) {
        setState(() {
          _segundosRestantes = restantes;
        });
        // Actualizar notificación con tiempo restante
        if (restantes % 5 == 0 || restantes < 10) {
          _actualizarNotificacion();
        }
      } else {
        // Time expired
        timer.cancel();
        _segundosRestantes = 0;
        // Verificar que el nativo no haya hecho ya el auto-stop
        if (mounted) {
          _autoStopPorTiempo();
        }
      }
    });
  }

  void _detenerTimer() {
    _timerAutoStop?.cancel();
    _timerAutoStop = null;
    _segundosRestantes = 0;
    _inicioGrabacion = null;
    _duracionTotalSegundos = 0;
  }

  Future<void> _autoStopPorTiempo() async {
    LoggerService().i('Auto-stop por tiempo completado');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiempo completado. Guardando recorrido...'),
        ),
      );
    }
    // Detener y guardar
    await _detenerGrabacionBackground();
    await _guardarRecorrido();
    // Notify parent to stop
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _actualizarNotificacion() async {
    // Actualizar notificación en el servicio nativo
    try {
      await BackgroundLocationPlugin.actualizarTiempo(_segundosRestantes);
      final mins = _segundosRestantes ~/ 60;
      final segs = _segundosRestantes % 60;
      final tiempoStr = mins > 0 ? '$mins min $segs seg' : '$segs seg';
      LoggerService().d('Tiempo restante: $tiempoStr');
    } catch (e) {
      // Ignorar errores de notificación
    }
  }

  Future<void> _detenerGrabacionBackground() async {
    LoggerService().i('Deteniendo grabacion...');
    _detenerTimer();

    try {
      await _iniciarServicioNativo(false);
      // Reactivar el stream de foreground para cuando no esté grabando
      _iniciarStreamGPS();
    } catch (e) {
      // Silenciar error al detener
    }
  }

  Future<bool> _solicitarPermisoNotificaciones() async {
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    final androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    final initSettings = InitializationSettings(android: androidSettings);

    await notifications.initialize(initSettings);

    // Solicitar permiso en Android 13+
    final android = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  Future<void> _verificarPermisos() async {
    // Verificar permiso de notificaciones (Android 13+)
    await _solicitarPermisoNotificaciones();

    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      throw Exception('GPS desactivado. Por favor enciende el GPS.');
    }

    // Verificar permiso actual
    LocationPermission permiso = await Geolocator.checkPermission();
    LoggerService().d('Permiso actual: $permiso');

    // Si no tiene permiso, solicitar
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      LoggerService().d('Permiso tras solicitud inicial: $permiso');
    }

    // Si denegado permanentemente, no se puede continuar
    if (permiso == LocationPermission.deniedForever) {
      throw Exception(
        'Permiso de ubicación denegado permanentemente. Habilita en ajustes.',
      );
    }

    // IMPORTANTE: Si tiene whileInUse, forzar solicitud de "always"
    // Hacer hasta 2 intentos de solicitar permiso "always"
    if (permiso == LocationPermission.whileInUse) {
      for (int intento = 0; intento < 2; intento++) {
        LoggerService().d(
          'Solicitando permiso always - intento ${intento + 1}',
        );

        // Usar requestPermission con LocationSettings para solicitar "always"
        LocationPermission permisoAlways = await Geolocator.requestPermission();
        LoggerService().d('Resultado permiso always: $permisoAlways');


        if (permisoAlways == LocationPermission.always) {
          LoggerService().d('Permiso "always" concedido!');
          break;
        }

        if (permisoAlways == LocationPermission.deniedForever) {
          throw Exception(
            'Permiso de fondo denegado permanentemente. Habilita en ajustes.',
          );
        }

        // Si se denegó, esperar un poco y reintentar
        if (permisoAlways == LocationPermission.denied) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    // Verificar permiso final
    LocationPermission permisoFinal = await Geolocator.checkPermission();
    LoggerService().d('Permiso final: $permisoFinal');

    if (permisoFinal != LocationPermission.always &&
        permisoFinal != LocationPermission.whileInUse) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nota: Solo se grabará cuando la app esté abierta. Para fondo en segundo plano, otorga permiso "Siempre" en ajustes.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _iniciarServicioNativo(
    bool iniciar, {
    int duracionMinutos = 0,
  }) async {
    try {
      if (iniciar) {
        await BackgroundLocationPlugin.startForegroundService(
          duracionMinutos: duracionMinutos,
        );
      } else {
        await BackgroundLocationPlugin.stopForegroundService();
      }
    } catch (e) {
      debugPrint('Error al controlar servicio: $e');
    }
  }

  Future<void> _irAMiUbicacion() async {
    if (posicionActual == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Obteniendo ubicación...')));
      return;
    }
    mapController.move(posicionActual!, 18);
  }

  Future<void> _guardarRecorrido() async {
    if (recorrido.isEmpty || _yaGuardo) return;

    _yaGuardo = true;

    try {
      final now = DateTime.now();
      // Usar el nombre proporcionado por el usuario, o generar uno por defecto
      final nombreFinal = widget.nombreRecorrido?.isNotEmpty == true
          ? widget.nombreRecorrido!
          : '${now.day}/${now.month}/${now.year} - ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      final recorridoSyncId =
          'REC_${widget.userId}_${now.microsecondsSinceEpoch}';

      // Crear nuevo recorrido
      final nuevoRecorrido = Recorrido(
        syncId: recorridoSyncId,
        userId: widget.userId,
        fecha: now,
        nombre: nombreFinal,
      );

      // Guardar en BD y obtener el ID
      final recorridoId = await _dbService.insertRecorrido(nuevoRecorrido);

      // Guardar todos los puntos
      final puntos = <PuntoGps>[];
      for (int i = 0; i < recorrido.length; i++) {
        puntos.add(
          PuntoGps(
            syncId: 'PTO_${recorridoSyncId}_$i',
            recorridoId: recorridoId,
            latitud: recorrido[i].latitude,
            longitud: recorrido[i].longitude,
            fechaHora: _fechasPuntos[i],
          ),
        );
      }

      await _dbService.insertPuntos(puntos);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recorrido guardado: $nombreFinal')),
        );
        widget.onRecorridoGuardado?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  Future<void> _iniciarUbicacion() async {
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();

    if (!servicioActivo) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GPS desactivado')));
      }
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
      }
      return;
    }

    // Intentar obtener última ubicación conocida
    try {
      final Position? ultimaUbicacion = await Geolocator.getLastKnownPosition();
      if (ultimaUbicacion != null) {
        final pos = LatLng(ultimaUbicacion.latitude, ultimaUbicacion.longitude);
        if (mounted) {
          setState(() {
            posicionActual = pos;
          });
        }
      }
    } catch (e) {
      // Ignorar error
    }
  }

  // Variable para evitar duplicados de puntos
  DateTime? _ultimoPuntoTiempo;
  String _ultimoProvider = '';
  double _ultimoAccuracy = 999.0;
  static const _minIntervaloMs =
      1200; // Min 1.2s entre puntos. Filtra duplicados de foreground+background.
      // A 1.2s, un peatón a 5km/h se mueve ~1.7m, dentro del ruido GPS (2-3m).

  // Variable para trackear si el stream de foreground ya está activo
  bool _streamForegoundActivo = false;

  Future<void> _iniciarStreamGPS() async {
    // Si el stream ya está activo, no crear otro
    if (_streamForegoundActivo && subscription != null) {
      LoggerService().d('Stream GPS foreground ya activo, no recrear');
      return;
    }

    // Cuando estamos grabando, mantenemos el stream de foreground activo como backup
    // Esto es importante: si el servicio nativo falla (teléfono bloqueado),
    // el stream de foreground sigue funcionando

    // Verificar permisos antes de iniciar el stream GPS (necesario para que actualice cuando no está grabando)
    bool servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GPS desactivado')));
      }
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    // Si no tiene permiso, solicitar
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    // Si todavía no tiene permiso, no continuar
    if (permiso == LocationPermission.denied) {
      return;
    }

    // Si denegado permanentemente, mostrar error
    if (permiso == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
      }
      return;
    }

    // Si tiene whileInUse, solicitar siempre para mejor tracking en segundo plano
    if (permiso == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
      // Si no dio permiso always, continuamos con whileInUse (funciona para foreground)
    }

    subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter:
                0, // 0 = obtener todos los puntos sin filtro de distancia
          ),
        ).listen((Position position) {
          _agregarPunto(
            position.latitude,
            position.longitude,
            accuracy: position.accuracy,
            provider: 'gps_foreground',
          );
        });

    // Marcar el stream como activo
    _streamForegoundActivo = true;
    LoggerService().d('Stream GPS foreground iniciado');
  }

  @override
  void dispose() {
    _cancelarSuscriptions();
    _tileProvider.dispose();
    super.dispose();
  }

  Future<void> _cancelarSuscriptions() async {
    subscription?.cancel();
    subscription = null;
    _bgLocationSubscription?.cancel();
    _bgLocationSubscription = null;
  }

  String _formatearTiempo(int segundos) {
    final mins = segundos ~/ 60;
    final segs = segundos % 60;
    return '${mins.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}';
  }

  // --- Indicador de calidad GPS ---

  Color _colorPorAccuracy(double accuracy) {
    if (!_esAccuracyValido(accuracy) || accuracy > 50.0) {
      return Colors.red;
    } else if (accuracy > 10.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _textoPorAccuracy(double accuracy) {
    if (!_esAccuracyValido(accuracy)) {
      return 'Sin señal';
    } else if (accuracy > 50.0) {
      return 'Débil';
    } else if (accuracy > 10.0) {
      return 'Regular';
    } else {
      return 'Óptimo';
    }
  }

  String _formatearAccuracy(double accuracy) {
    if (!_esAccuracyValido(accuracy)) return '-';
    if (accuracy >= 1000) {
      return '${(accuracy / 1000).toStringAsFixed(1)} km';
    }
    return '${accuracy.toStringAsFixed(0)} m';
  }

  Widget _buildGpsIndicator() {
    final accuracy = _ultimoAccuracy;
    final color = _colorPorAccuracy(accuracy);
    final texto = _textoPorAccuracy(accuracy);
    final valor = _formatearAccuracy(accuracy);
    final tieneSenhal = _esAccuracyValido(accuracy);

    return Positioned(
      bottom: 12,
      left: 12,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de pulso animado
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GPS $texto',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (tieneSenhal)
                    Text(
                      '±$valor',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usar la posición inicial si no hay ubicación todavía
    final center = _centerInicial ?? posicionActual;

    if (center == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: center, initialZoom: 18),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.david.georuta',
                tileProvider: _tileProvider,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: posicionActual ?? center,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_pin,
                      size: 40,
                      color: widget.recorriendo ? Colors.red : Colors.blue,
                    ),
                  ),
                ],
              ),
              if (recorrido.length >= 2)
                PolylineLayer(
                  polylines: [Polyline(points: recorrido, strokeWidth: 5)],
                ),
            ],
          ),
          // Badge de consumo de datos
          const Positioned(top: 12, left: 12, child: MapDataUsageBadge()),
          
          // Timer display (cuando está grabando con duración)
          if (widget.recorriendo && _segundosRestantes > 0)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatearTiempo(_segundosRestantes),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Indicador de calidad GPS
          _buildGpsIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _irAMiUbicacion,
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}
