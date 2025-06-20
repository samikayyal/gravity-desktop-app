import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trampoline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // This runs only the first time the database is created
  Future<void> _createDB(Database db, int version) async {
    // any date is stored as TEXT in ISO 8601 format
    await db.execute('''
      CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        last_played TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_players(
        player_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        time_reserved TEXT NOT NULL,
        amount_owed INTEGER NOT NULL,
        amount_paid INTEGER NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS phone_numbers(
        player_id INTEGER NOT NULL,
        phone_number TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS prices(
        time_slice TEXT PRIMARY KEY,
        price INTEGER NOT NULL
      )
    ''');

    // Insert default prices if they do not exist
    await db.execute('''
      INSERT OR IGNORE INTO prices (time_slice, price) VALUES
      ('hour', 0),
      ('half_hour', 0),
      ('additional_hour', 0),
      ('additional_half_hour', 0)
    ''');
  }
}
