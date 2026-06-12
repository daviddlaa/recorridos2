import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final String nombreInicial;

  const CrearUsuarioScreen({super.key, required this.nombreInicial});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _nombreController = TextEditingController();
  final _claveController = TextEditingController();
  final _confirmarClaveController = TextEditingController();
  final _dbService = DbService();

  bool _cargando = false;
  bool _mostrarClave = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.nombreInicial;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _claveController.dispose();
    _confirmarClaveController.dispose();
    super.dispose();
  }

  String _generarId() {
    final now = DateTime.now();
    return 'USR${now.millisecondsSinceEpoch}';
  }

  Future<void> _crearUsuario() async {
    final nombre = _nombreController.text.trim();
    final clave = _claveController.text.trim();
    final confirmarClave = _confirmarClaveController.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'Ingresa un usuario');
      return;
    }
    if (clave.isEmpty) {
      setState(() => _error = 'Ingresa una contrasena');
      return;
    }
    if (clave != confirmarClave) {
      setState(() => _error = 'Las contrasenas no coinciden');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuarioExistente = await _dbService.getUsuarioByNombre(nombre);
      if (!mounted) return;

      if (usuarioExistente != null) {
        setState(() => _error = 'Ese usuario ya existe');
        return;
      }

      final nuevoUsuario = Usuario(
        id: _generarId(),
        nombre: nombre,
        claveSincronizacion: clave,
        fechaCreado: DateTime.now(),
      );

      await _dbService.insertUsuario(nuevoUsuario);

      if (mounted) {
        Navigator.pop(context, nuevoUsuario);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final temaActual = ThemeService.currentTheme;
    final theme = AppTheme.getThemeData(temaActual, ThemeService.isDarkMode);

    return Theme(
      data: theme,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Nuevo Usuario',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onSubmitted: (_) => _crearUsuario(),
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
                ),
                onSubmitted: (_) => _crearUsuario(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmarClaveController,
                obscureText: !_mostrarClave,
                decoration: InputDecoration(
                  labelText: 'Confirmar contrasena',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  errorText: _error,
                ),
                onSubmitted: (_) => _crearUsuario(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _cargando ? null : _crearUsuario,
                  icon: _cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_cargando ? 'Creando...' : 'CREAR USUARIO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
