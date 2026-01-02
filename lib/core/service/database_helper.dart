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
      version: 4,  // Phase 4: 升级版本号 (添加 prompt_logs 表)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 事实表 (Fact Store) - Phase 2: 添加 status 列
    await db.execute('''
      CREATE TABLE facts (
        key TEXT PRIMARY KEY,
        value TEXT,
        source INTEGER DEFAULT 1,
        timestamp TEXT,
        importance REAL DEFAULT 0.5,
        status INTEGER DEFAULT 0
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
    
    // 记忆表 (Memory Entries) - Phase 3: 解决大规模记忆存储瓶颈
    await db.execute('''
      CREATE TABLE memory_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        importance REAL DEFAULT 0.5
      )
    ''');
    
    // 创建时间索引以加速按时间检索
    await db.execute('''
      CREATE INDEX idx_memory_timestamp ON memory_entries(timestamp DESC)
    ''');
    
    // Prompt 日志表 (Phase 4: Prompt Viewer/Storage)
    await db.execute('''
      CREATE TABLE prompt_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT NOT NULL,
        layer TEXT NOT NULL,
        prompt_content TEXT NOT NULL,
        response_content TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_prompt_message ON prompt_logs(message_id)
    ''');
  }
  
  /// Phase 2/3/4: 数据库升级迁移
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加 status 列：0=active, 1=verified, 2=rejected
      await db.execute('ALTER TABLE facts ADD COLUMN status INTEGER DEFAULT 0');
      print('[DatabaseHelper] Migrated to version 2: added status column');
    }
    if (oldVersion < 3) {
      // Phase 3: 添加 memory_entries 表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS memory_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          importance REAL DEFAULT 0.5
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_memory_timestamp ON memory_entries(timestamp DESC)
      ''');
      print('[DatabaseHelper] Migrated to version 3: added memory_entries table');
    }
    if (oldVersion < 4) {
      // Phase 4: 添加 prompt_logs 表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS prompt_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id TEXT NOT NULL,
          layer TEXT NOT NULL,
          prompt_content TEXT NOT NULL,
          response_content TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_prompt_message ON prompt_logs(message_id)
      ''');
      print('[DatabaseHelper] Migrated to version 4: added prompt_logs table');
    }
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
