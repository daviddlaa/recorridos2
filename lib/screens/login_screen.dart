import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/db_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import 'crear_usuario_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _claveController = TextEditingController();
  final DbService _dbService = DbService();
  bool _cargando = false;
  bool _mostrarClave = false;
  String? _error;
  int _temaSeleccionado = 0;

  @override
  void dispose() {
    _nombreController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  String _generarId() {
    final now = DateTime.now();
    return 'USR${now.millisecondsSinceEpoch}';
  }

  Future<void> _iniciarSesion() async {
    final nombre = _nombreController.text.trim();
    final clave = _claveController.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa tu nombre');
      return;
    }
    if (clave.isEmpty) {
      setState(() => _error = 'Ingresa tu contrasena');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuario = await _dbService.getUsuarioByNombre(nombre);
      if (!mounted) return;

      if (usuario == null) {
        final nuevoUsuario = Usuario(
          id: _generarId(),
          nombre: nombre,
          claveSincronizacion: clave,
          fechaCreado: DateTime.now(),
        );
        await _dbService.insertUsuario(nuevoUsuario);
        if (!mounted) return;
        _irAHome(nuevoUsuario);
        return;
      }

      if (usuario.claveSincronizacion.isEmpty) {
        final usuarioActualizado = Usuario(
          id: usuario.id,
          nombre: usuario.nombre,
          claveSincronizacion: clave,
          fechaCreado: usuario.fechaCreado,
        );
        await _dbService.updateUsuario(usuarioActualizado);
        if (!mounted) return;
        _irAHome(usuarioActualizado);
        return;
      }

      if (usuario.claveSincronizacion == clave) {
        _irAHome(usuario);
        return;
      }

      setState(() {
        _cargando = false;
        _error = 'Usuario o contrasena incorrectos';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error: $e';
      });
    }
  }

  void _irAHome(Usuario usuario) {
    ThemeService.setThemeByIndex(_temaSeleccionado);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(usuario: usuario)),
    );
  }

  void _irACrearUsuario() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CrearUsuarioScreen(nombreInicial: _nombreController.text.trim()),
      ),
    ).then((usuarioCreado) {
      if (usuarioCreado != null && usuarioCreado is Usuario) {
        _irAHome(usuarioCreado);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final temaActual = AppThemeOptions.getThemeByIndex(_temaSeleccionado);
    final theme = AppTheme.getThemeData(
      temaActual,
      temaActual.name == 'Dark Moderno',
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Bienvenido a GeoRuta',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Selecciona un color:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                _SelectorColores(
                  seleccionado: _temaSeleccionado,
                  onSelect: (index) =>
                      setState(() => _temaSeleccionado = index),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nombreController,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  onSubmitted: (_) => _iniciarSesion(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _claveController,
                  obscureText: !_mostrarClave,
                  decoration: InputDecoration(
                    labelText: 'Contrasena',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _mostrarClave = !_mostrarClave),
                      icon: Icon(
                        _mostrarClave ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _iniciarSesion(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _cargando ? null : _iniciarSesion,
                    icon: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_cargando ? 'Entrando...' : 'ENTRAR'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _cargando ? null : _irACrearUsuario,
                    icon: const Icon(Icons.person_add),
                    label: const Text('CREAR NUEVO USUARIO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorColores extends StatelessWidget {
  final int seleccionado;
  final Function(int) onSelect;

  const _SelectorColores({required this.seleccionado, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(AppThemeOptions.themes.length, (index) {
        final tema = AppThemeOptions.themes[index];
        final esSeleccionado = index == seleccionado;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: esSeleccionado ? 50 : 40,
            height: esSeleccionado ? 50 : 40,
            decoration: BoxDecoration(
              color: tema.primary,
              shape: BoxShape.circle,
              border: esSeleccionado
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: esSeleccionado
                  ? [
                      BoxShadow(
                        color: tema.primary.withAlpha(128),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: esSeleccionado
                ? Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
        );
      }),
    );
  }
}
