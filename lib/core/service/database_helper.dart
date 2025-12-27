import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop initialization using sqflite_common_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await getApplicationSupportDirectory();
      path = join(directory.path, 'ai_companion.db');
    } else {
      path = join(await getDatabasesPath(), 'ai_companion.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 事实表 (Fact Store)
    await db.execute('''
      CREATE TABLE facts (
        key TEXT PRIMARY KEY,
        value TEXT,
        source INTEGER DEFAULT 1,
        timestamp TEXT,
        importance REAL DEFAULT 0.5
      )
    ''');

    // 消息表 (Chat History)
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        time TEXT NOT NULL,
        full_prompt TEXT,
        tokens_used INTEGER,
        cognitive_state TEXT
      )
    ''');
  }

  // 通用辅助方法
  Future<int> insert(String table, Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    Database db = await database;
    return await db.query(table);
  }

  Future<int> update(String table, Map<String, dynamic> row, String keyColumn) async {
    Database db = await database;
    String key = row[keyColumn];
    return await db.update(table, row, where: '$keyColumn = ?', whereArgs: [key]);
  }

  Future<int> delete(String table, String keyColumn, dynamic key) async {
    Database db = await database;
    return await db.delete(table, where: '$keyColumn = ?', whereArgs: [key]);
  }

  Future<void> clearTable(String table) async {
    Database db = await database;
    await db.delete(table);
  }
}
