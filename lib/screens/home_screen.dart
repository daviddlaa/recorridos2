// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../widgets/map_widget.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'historial_screen.dart';
import 'logs_screen.dart';
import 'mapa_historico_screen.dart';
import 'sincronizacion_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Usuario usuario;

  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool recorriendo = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Duración seleccionada en minutos (null = manual)
  int? duracionSeleccionada;

  // Nombre del recorridoingresado por el usuario
  String? nombreRecorrido;

  void _recorridoGuardado() {
    // Cuando se guarda el recorrido (por auto-stop o manual), resetear el estado
    setState(() {
      recorriendo = false;
      duracionSeleccionada = null;
      nombreRecorrido = null;
    });
  }

  Future<void> _mostrarDialogoDuracion() async {
    final nombreController = TextEditingController();
    int? duracionTemp;
    String? errorMensaje;

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Iniciar Recorrido'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar duración:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setStateDialog(() => duracionTemp = 60),
                  child: ListTile(
                    title: const Text('1 hora'),
                    leading: Radio<int?>(
                      value: 60,
                      groupValue: duracionTemp,
                      onChanged: (v) => setStateDialog(() => duracionTemp = v),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setStateDialog(() => duracionTemp = 120),
                  child: ListTile(
                    title: const Text('2 horas'),
                    leading: Radio<int?>(
                      value: 120,
                      groupValue: duracionTemp,
                      onChanged: (v) => setStateDialog(() => duracionTemp = v),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    _mostrarTimePicker();
                  },
                  child: const ListTile(title: Text('Personalizado')),
                ),
                InkWell(
                  onTap: () => setStateDialog(() => duracionTemp = null),
                  child: ListTile(
                    title: const Text('Sin límite (manual)'),
                    leading: Radio<int?>(
                      value: null,
                      groupValue: duracionTemp,
                      onChanged: (v) => setStateDialog(() => duracionTemp = v),
                    ),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Nombre del recorrido *:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    hintText: 'Ej: recorrido Playas centro',
                    border: const OutlineInputBorder(),
                    errorText: errorMensaje,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  setStateDialog(() {
                    errorMensaje = 'El nombre es obligatorio';
                  });
                  return;
                }
                Navigator.pop(context, {
                  'duracion': duracionTemp,
                  'nombre': nombre,
                });
              },
              child: const Text('Iniciar'),
            ),
          ],
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        recorriendo = true;
        duracionSeleccionada = resultado['duracion'] as int?;
        nombreRecorrido = resultado['nombre'] as String;
      });
    }
  }

  Future<void> _mostrarTimePicker() async {
    int minutosPersonalizados = 30;

    final resultado = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duración personalizada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona los minutos:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (int mins in [15, 30, 45, 60, 90])
                  ActionChip(
                    label: Text('$mins min'),
                    onPressed: () => Navigator.pop(context, mins),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Otros minutos',
                hintText: 'Ej: 20',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null && parsed > 0) {
                  minutosPersonalizados = parsed;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, minutosPersonalizados),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (resultado != null && resultado > 0) {
      setState(() {
        recorriendo = true;
        duracionSeleccionada = resultado;
      });
    }
  }

  void _detenerRecorrido() {
    setState(() {
      recorriendo = false;
      duracionSeleccionada = null;
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _navigateTo(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final temaActual = ThemeService.currentTheme;
    final theme = AppTheme.getThemeData(temaActual, ThemeService.isDarkMode);

    return Theme(
      data: theme,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('GeoRuta - ${widget.usuario.nombre}'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _openDrawer,
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: temaActual.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      widget.usuario.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Clave: ${widget.usuario.claveSincronizacion}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.sync, color: temaActual.primary),
                title: const Text('Sincronizacion'),
                onTap: () => _navigateTo(const SincronizacionScreen()),
              ),
              ListTile(
                leading: Icon(Icons.terminal, color: temaActual.primary),
                title: const Text('Logs'),
                onTap: () => _navigateTo(const LogsScreen()),
              ),
              ListTile(
                leading: Icon(Icons.history, color: temaActual.primary),
                title: const Text('Historial'),
                onTap: () =>
                    _navigateTo(HistorialScreen(usuario: widget.usuario)),
              ),
              ListTile(
                leading: Icon(Icons.map, color: temaActual.primary),
                title: const Text('Mapa Historico'),
                onTap: () => _navigateTo(const MapaHistoricoScreen()),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Cerrar sesion',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: MapWidget(
                recorriendo: recorriendo,
                userId: widget.usuario.id,
                onRecorridoGuardado: _recorridoGuardado,
                duracionMinutos: duracionSeleccionada,
                nombreRecorrido: nombreRecorrido,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (recorriendo) {
                      _detenerRecorrido();
                    } else {
                      _mostrarDialogoDuracion();
                    }
                  },
                  icon: Icon(recorriendo ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    recorriendo
                        ? "DETENER RECORRIDO"
                        : "INICIAR RECORRIDO${duracionSeleccionada != null ? ' (${duracionSeleccionada}m)' : ''}",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
