import 'package:flutter/material.dart';

import '../services/map_data_usage_service.dart';

class MapDataUsageBadge extends StatefulWidget {
  const MapDataUsageBadge({super.key});

  @override
  State<MapDataUsageBadge> createState() => _MapDataUsageBadgeState();
}

class _MapDataUsageBadgeState extends State<MapDataUsageBadge> {
  final _usageService = MapDataUsageService.instance;

  @override
  void initState() {
    super.initState();
    _usageService.inicializar();
  }

  Future<void> _confirmarReinicio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar contador'),
        content: const Text('Deseas reiniciar el consumo de mapas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _usageService.reiniciar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _usageService.bytesNotifier,
      builder: (context, bytes, _) {
        return Material(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.data_usage, size: 18, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'Mapas: ${_usageService.formatearBytes(bytes)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  tooltip: 'Reiniciar contador',
                  onPressed: _confirmarReinicio,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
