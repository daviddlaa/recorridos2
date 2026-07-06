import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recorrido.dart';
import '../models/punto_gps.dart';
import '../models/usuario.dart';

class DbService {
  static Database? _database;
  static const String _dbName = 'georuta.db';
  static const int _dbVersion = 4;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE usuarios (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        clave_sincronizacion TEXT NOT NULL,
        fecha_creado TEXT NOT NULL
      )
    ''');

    // Tabla de recorridos (cada día es un recorrido)
    await db.execute('''
      CREATE TABLE recorridos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE,
        user_id TEXT,
        fecha TEXT NOT NULL,
        nombre TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES usuarios (id)
      )
    ''');

    // Tabla de puntos GPS
    await db.execute('''
      CREATE TABLE puntos_gps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE,
        recorrido_id INTEGER NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        fecha_hora TEXT NOT NULL,
        FOREIGN KEY (recorrido_id) REFERENCES recorridos (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_config (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Si actualizamos de versión 1 a 2, agregar columna user_id (nullable)
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE recorridos ADD COLUMN user_id TEXT');
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'recorridos', 'sync_id', 'TEXT');
      await _addColumnIfMissing(db, 'puntos_gps', 'sync_id', 'TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_config (
          clave TEXT PRIMARY KEY,
          valor TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // --- Métodos para Usuarios ---

  Future<int> insertUsuario(Usuario usuario) async {
    final db = await database;
    return await db.insert('usuarios', usuario.toMap());
  }

  Future<List<Usuario>> getAllUsuarios() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('usuarios');
    return List.generate(maps.length, (i) => Usuario.fromMap(maps[i]));
  }

  Future<Usuario?> getUsuarioById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  Future<Usuario?> getUsuarioByNombre(String nombre) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'LOWER(nombre) = LOWER(?)',
      whereArgs: [nombre],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  Future<int> updateUsuario(Usuario usuario) async {
    final db = await database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<int> deleteUsuario(String id) async {
    final db = await database;
    return await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> validarClaveSincronizacion(String userId, String clave) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'id = ? AND clave_sincronizacion = ?',
      whereArgs: [userId, clave],
    );
    return maps.isNotEmpty;
  }

  Future<bool> validarLogin(String nombre, String clave) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'usuarios',
      where: 'LOWER(nombre) = LOWER(?) AND clave_sincronizacion = ?',
      whereArgs: [nombre, clave],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // --- Métodos para Recorridos ---

  Future<int> insertRecorrido(Recorrido recorrido) async {
    final db = await database;
    return await db.insert('recorridos', recorrido.toMap());
  }

  Future<List<Recorrido>> getAllRecorridos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recorridos',
      orderBy: 'fecha DESC',
    );
    return List.generate(maps.length, (i) => Recorrido.fromMap(maps[i]));
  }

  Future<List<Recorrido>> getRecorridosByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recorridos',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'fecha DESC',
    );
    return List.generate(maps.length, (i) => Recorrido.fromMap(maps[i]));
  }

  Future<Recorrido?> getRecorridoByFecha(DateTime fecha) async {
    final db = await database;
    final fechaStr = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
    ).toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.query(
      'recorridos',
      where: "fecha LIKE ?",
      whereArgs: ['$fechaStr%'],
    );

    if (maps.isEmpty) return null;
    return Recorrido.fromMap(maps.first);
  }

  Future<Recorrido?> getRecorridoBySyncId(String syncId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recorridos',
      where: 'sync_id = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Recorrido.fromMap(maps.first);
  }

  Future<int> deleteRecorrido(int id) async {
    final db = await database;
    // Primero borrar los puntos
    await db.delete('puntos_gps', where: 'recorrido_id = ?', whereArgs: [id]);
    // Luego borrar el recorrido
    return await db.delete('recorridos', where: 'id = ?', whereArgs: [id]);
  }

  // --- Métodos para Puntos GPS ---

  Future<int> insertPunto(PuntoGps punto) async {
    final db = await database;
    return await db.insert('puntos_gps', punto.toMap());
  }

  Future<bool> existePuntoBySyncId(String syncId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'puntos_gps',
      columns: ['id'],
      where: 'sync_id = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<void> insertPuntos(List<PuntoGps> puntos) async {
    final db = await database;
    final batch = db.batch();
    for (final punto in puntos) {
      batch.insert('puntos_gps', punto.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<PuntoGps>> getPuntosByRecorridoId(int recorridoId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'puntos_gps',
      where: 'recorrido_id = ?',
      whereArgs: [recorridoId],
      orderBy: 'fecha_hora ASC',
    );
    return List.generate(maps.length, (i) => PuntoGps.fromMap(maps[i]));
  }

  /// Carga puntos de múltiples recorridos en UNA sola consulta SQL.
  /// Retorna un mapa: recorridoId -> lista de puntos.
  Future<Map<int, List<PuntoGps>>> getPuntosByRecorridoIds(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return {};
    final db = await database;

    // Construir placeholders (?, ?, ?...)
    final placeholders = ids.map((_) => '?').join(',');
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT * FROM puntos_gps WHERE recorrido_id IN ($placeholders) ORDER BY recorrido_id, fecha_hora ASC',
      ids,
    );

    final Map<int, List<PuntoGps>> resultado = {};
    for (final map in maps) {
      final punto = PuntoGps.fromMap(map);
      resultado.putIfAbsent(punto.recorridoId, () => []).add(punto);
    }
    return resultado;
  }

  Future<int> deletePuntosByRecorridoId(int recorridoId) async {
    final db = await database;
    return await db.delete(
      'puntos_gps',
      where: 'recorrido_id = ?',
      whereArgs: [recorridoId],
    );
  }

  Future<void> asegurarSyncIds() async {
    final db = await database;
    final recorridos = await db.query(
      'recorridos',
      where: 'sync_id IS NULL OR sync_id = ?',
      whereArgs: [''],
    );
    for (final recorrido in recorridos) {
      final id = recorrido['id'];
      final fecha = recorrido['fecha'];
      final userId = recorrido['user_id'] ?? 'sin_usuario';
      await db.update(
        'recorridos',
        {'sync_id': 'REC_${userId}_${id}_$fecha'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    final puntos = await db.query(
      'puntos_gps',
      where: 'sync_id IS NULL OR sync_id = ?',
      whereArgs: [''],
    );
    for (final punto in puntos) {
      final id = punto['id'];
      final recorridoId = punto['recorrido_id'];
      final fechaHora = punto['fecha_hora'];
      await db.update(
        'puntos_gps',
        {'sync_id': 'PTO_${recorridoId}_${id}_$fechaHora'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<int> getMapDataUsageBytes() async {
    final db = await database;
    final maps = await db.query(
      'app_config',
      where: 'clave = ?',
      whereArgs: ['map_data_usage_bytes'],
      limit: 1,
    );
    if (maps.isEmpty) return 0;
    return int.tryParse(maps.first['valor'] as String) ?? 0;
  }

  // --- Métodos para Recorridos por Rango de Fechas ---

  Future<List<Recorrido>> getRecorridosByFechaRango(
    DateTime desde,
    DateTime hasta,
  ) async {
    final db = await database;
    // Normalizar fechas a inicio y fin del día
    final desdeStr = DateTime(
      desde.year,
      desde.month,
      desde.day,
    ).toIso8601String();
    final hastaStr = DateTime(
      hasta.year,
      hasta.month,
      hasta.day,
      23,
      59,
      59,
    ).toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'recorridos',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [desdeStr, hastaStr],
      orderBy: 'fecha ASC',
    );
    return List.generate(maps.length, (i) => Recorrido.fromMap(maps[i]));
  }

  Future<void> setMapDataUsageBytes(int bytes) async {
    final db = await database;
    await db.insert('app_config', {
      'clave': 'map_data_usage_bytes',
      'valor': bytes.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
