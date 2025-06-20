import 'package:gravity_desktop_app/models/player.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum TimeSlice {
  hour,
  halfHour,
  additionalHour,
  additionalHalfHour,
}

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

    // players table stores player information
    await db.execute('''
      CREATE TABLE IF NOT EXISTS players (
        id TEXT PRIMARY KEY, -- UUID for each player
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        last_modified TEXT NOT NULL
      )
    ''');

    // The state (current/past) is determined by 'check_out_time'.
    await db.execute('''
    CREATE TABLE IF NOT EXISTS player_sessions (
      session_id INTEGER PRIMARY KEY AUTOINCREMENT,
      player_id TEXT NOT NULL,
      check_in_time TEXT NOT NULL,
      time_reserved_hours INTEGER NOT NULL,
      time_reserved_minutes INTEGER NOT NULL,
      is_open_time INTEGER NOT NULL,     -- 0 for false, 1 for true
      check_out_time TEXT,               -- *** NULL means this session is ACTIVE ***
      amount_owed INTEGER NOT NULL,         
      amount_paid INTEGER NOT NULL,
      last_modified TEXT NOT NULL,       --  for syncing new sessions.
      FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
    )
  ''');

    // phone_numbers table stores phone numbers for players
    await db.execute('''
      CREATE TABLE IF NOT EXISTS phone_numbers(
        player_id TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    // prices table stores the prices for different time slices
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

  // get the  current players
  Future<List<Player>> getCurrentPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT ps.player_id,
              p.name,
              p.age,
              ps.check_in_time,
              ps.time_reserved_hours,
              ps.time_reserved_minutes,
              ps.is_open_time,
              ps.amount_owed,
              ps.amount_paid,
              ps.session_id
      FROM player_sessions ps
      JOIN players p ON ps.player_id = p.id
      WHERE ps.check_out_time IS NULL
    ''');
    return result.map((map) => Player.fromMap(map)).toList();
  }

  // Check out a player by session ID
  Future<void> checkOutPlayer(int sessionId) async {
    final db = await database;
    await db.update(
      'player_sessions',
      {
        'check_out_time': DateTime.now().toUtc().toIso8601String(),
        'last_modified': DateTime.now().toUtc().toIso8601String()
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // Check in a player
  Future<void> checkInPlayer(Player player) async {
    final db = await database;
    await db.insert(
      'player_sessions',
      {
        'player_id': player.playerID,
        'check_in_time': player.checkInTime.toIso8601String(),
        'time_reserved_hours': player.timeReserved.inHours,
        'time_reserved_minutes': player.timeReserved.inMinutes % 60,
        'is_open_time': player.isOpenTime ? 1 : 0,
        'amount_owed': player.amountOwed,
        'amount_paid': player.amountPaid,
        'last_modified': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<TimeSlice, int>> getPrices() async {
    final db = await database;

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT time_slice, price FROM prices',
    );
    final Map<TimeSlice, int> prices = {};
    for (var row in result) {
      final timeSlice = row['time_slice'] as String;
      final price = row['price'] as int;

      switch (timeSlice) {
        case 'hour':
          prices[TimeSlice.hour] = price;
          break;
        case 'half_hour':
          prices[TimeSlice.halfHour] = price;
          break;
        case 'additional_hour':
          prices[TimeSlice.additionalHour] = price;
          break;
        case 'additional_half_hour':
          prices[TimeSlice.additionalHalfHour] = price;
          break;
      }
    }
    return prices;
  }
}
