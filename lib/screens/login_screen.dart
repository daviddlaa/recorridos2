import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/db_service.dart';
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
    final colores = ThemeService.currentTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Logo de la app (misma forma que el icono launch)
              _AppLogo(primary: colores.primary, secondary: colores.secondary),
              const SizedBox(height: 8),
              Text(
                'GeoRuta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colores.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tus rutas, siempre contigo',
                style: TextStyle(
                  fontSize: 14,
                  color: colores.primary.withAlpha(180),
                ),
              ),
              const SizedBox(height: 40),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget que representa el logo de la app, inspirado en el icono launch.
/// Muestra un pin de ubicación blanco sobre un círculo azul,
/// con una línea naranja decorativa debajo (como la ruta en el icono).
class _AppLogo extends StatelessWidget {
  final Color primary;
  final Color secondary;

  const _AppLogo({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Círculo azul con pin blanco
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primary.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            size: 52,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        // Línea decorativa naranja (representa la ruta del icono launch)
        Container(
          width: 60,
          height: 3,
          decoration: BoxDecoration(
            color: secondary,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: secondary.withAlpha(100),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
