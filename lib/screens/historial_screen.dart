import 'package:flutter/material.dart';
import '../models/recorrido.dart';
import '../models/usuario.dart';
import '../services/db_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'recorrido_screen.dart';

class HistorialScreen extends StatefulWidget {
  final Usuario? usuario;

  const HistorialScreen({super.key, this.usuario});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final DbService _dbService = DbService();
  List<Recorrido> _recorridos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarRecorridos();
  }

  Future<void> _cargarRecorridos() async {
    setState(() => _cargando = true);
    try {
      List<Recorrido> todos = await _dbService.getAllRecorridos();
      List<Recorrido> recorridos;
      if (widget.usuario != null) {
        recorridos = todos
            .where(
              (r) =>
                  r.userId == widget.usuario!.id ||
                  r.userId == null ||
                  r.userId!.isEmpty,
            )
            .toList();
      } else {
        recorridos = todos;
      }
      setState(() {
        _recorridos = recorridos;
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

  Future<void> _eliminarRecorrido(Recorrido recorrido) async {
    if (recorrido.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recorrido'),
        content: Text('Eliminar "${recorrido.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _dbService.deleteRecorrido(recorrido.id!);
      _cargarRecorridos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final temaActual = ThemeService.currentTheme;
    final theme = AppTheme.getThemeData(temaActual, ThemeService.isDarkMode);
    final titulo = widget.usuario != null
        ? 'Historial - ${widget.usuario!.nombre}'
        : 'Historial de Recorridos';

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: Text(titulo), centerTitle: true),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _recorridos.isEmpty
            ? const Center(child: Text('No hay recorridos guardados'))
            : ListView.builder(
                itemCount: _recorridos.length,
                itemBuilder: (context, index) {
                  final recorrido = _recorridos[index];
                  final tieneUsuario =
                      recorrido.userId != null && recorrido.userId!.isNotEmpty;
                  return ListTile(
                    title: Text(recorrido.nombre),
                    subtitle: Row(
                      children: [
                        Icon(
                          tieneUsuario ? Icons.person : Icons.storage,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(tieneUsuario ? 'Mi recorrido' : 'Sin asignar'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _eliminarRecorrido(recorrido),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecorridoScreen(recorrido: recorrido),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
