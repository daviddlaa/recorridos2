import 'package:flutter/material.dart';
import '../services/local_sync_server.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

class SincronizacionScreen extends StatefulWidget {
  const SincronizacionScreen({super.key});

  @override
  State<SincronizacionScreen> createState() => _SincronizacionScreenState();
}

class _SincronizacionScreenState extends State<SincronizacionScreen> {
  final LocalSyncServer _server = LocalSyncServer();
  final LocalSyncClient _client = LocalSyncClient();
  final _ipController = TextEditingController();
  final _puertoController = TextEditingController();
  final _claveController = TextEditingController();

  bool _cargandoServidor = false;
  bool _enviando = false;
  String? _mensaje;
  String? _error;

  AppColors get _coloresActuales => ThemeService.currentTheme;
  bool get _isDarkMode => ThemeService.isDarkMode;

  @override
  void initState() {
    super.initState();
    _server.onImportResult = (resultado) {
      if (!mounted) return;
      setState(() {
        _mensaje =
            'Recibido. Usuarios: ${resultado.usuariosCreados}, recorridos: ${resultado.recorridosAgregados}, puntos: ${resultado.puntosAgregados}, duplicados: ${resultado.duplicadosIgnorados}';
        _error = null;
      });
    };
  }

  @override
  void dispose() {
    _server.detener();
    _ipController.dispose();
    _puertoController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _iniciarServidor() async {
    setState(() {
      _cargandoServidor = true;
      _mensaje = null;
      _error = null;
    });

    try {
      await _server.iniciar();
      if (!mounted) return;
      setState(() {
        _cargandoServidor = false;
        _mensaje = 'Servidor listo';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoServidor = false;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _detenerServidor() async {
    await _server.detener();
    if (!mounted) return;
    setState(() {
      _mensaje = 'Servidor detenido';
      _error = null;
    });
  }

  Future<void> _enviarDatos() async {
    final ip = _ipController.text.trim();
    final puerto = int.tryParse(_puertoController.text.trim());
    final clave = _claveController.text.trim();

    if (ip.isEmpty || puerto == null || clave.length != 6) {
      setState(() {
        _error = 'Ingresa IP, puerto y clave de 6 digitos';
        _mensaje = null;
      });
      return;
    }

    setState(() {
      _enviando = true;
      _mensaje = null;
      _error = null;
    });

    try {
      final respuesta = await _client.enviarDatos(
        ip: ip,
        puerto: puerto,
        clave: clave,
      );
      final resultado = respuesta['resultado'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _mensaje =
            'Enviado. Usuarios: ${resultado['usuarios_creados']}, recorridos: ${resultado['recorridos_agregados']}, puntos: ${resultado['puntos_agregados']}, duplicados: ${resultado['duplicados_ignorados']}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.getThemeData(_coloresActuales, _isDarkMode);
    final servidorActivo = _server.activo;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sincronizacion'), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Panel(
              title: 'Recibir datos',
              children: [
                if (servidorActivo) ...[
                  _DatoServidor(
                    label: 'IP',
                    value: _server.ip ?? 'No detectada',
                  ),
                  _DatoServidor(label: 'Puerto', value: '${_server.puerto}'),
                  _DatoServidor(label: 'Clave', value: _server.clave ?? ''),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: servidorActivo
                      ? OutlinedButton.icon(
                          onPressed: _detenerServidor,
                          icon: const Icon(Icons.stop),
                          label: const Text('DETENER'),
                        )
                      : ElevatedButton.icon(
                          onPressed: _cargandoServidor
                              ? null
                              : _iniciarServidor,
                          icon: _cargandoServidor
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi),
                          label: Text(
                            _cargandoServidor ? 'Iniciando...' : 'RECIBIR',
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Enviar datos',
              children: [
                TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'IP del servidor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.router),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _puertoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.settings_ethernet),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claveController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Clave',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviarDatos,
                    icon: _enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_enviando ? 'Enviando...' : 'ENVIAR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_mensaje != null)
              _EstadoBox(texto: _mensaje!, color: Colors.green),
            if (_error != null) _EstadoBox(texto: _error!, color: Colors.red),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Panel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DatoServidor extends StatelessWidget {
  final String label;
  final String value;

  const _DatoServidor({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _EstadoBox extends StatelessWidget {
  final String texto;
  final Color color;

  const _EstadoBox({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto, style: TextStyle(color: color)),
    );
  }
}
