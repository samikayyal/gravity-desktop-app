import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

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
      -- player info
      session_id INTEGER PRIMARY KEY AUTOINCREMENT,
      player_id TEXT NOT NULL,

      -- session info
      check_in_time TEXT NOT NULL,
      time_reserved_hours INTEGER NOT NULL,
      time_reserved_minutes INTEGER NOT NULL,
      is_open_time INTEGER NOT NULL,     -- 0 for false, 1 for true
      check_out_time TEXT,               -- *** NULL means this session is ACTIVE ***

      -- payment info
      initial_fee INTEGER NOT NULL DEFAULT 0,
      prepaid_amount INTEGER NOT NULL DEFAULT 0,
      last_modified TEXT NOT NULL,       
      FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE SET NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS sales(
      sale_id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER,               -- NULL if it's a separate (e.g. walk-in) purchase
      final_fee INTEGER NOT NULL,    -- Total value of the sale (session fee + products)
      amount_paid INTEGER NOT NULL,
      tips INTEGER NOT NULL DEFAULT 0,
      sale_time TEXT NOT NULL,
      last_modified TEXT NOT NULL,
      FOREIGN KEY (session_id) REFERENCES player_sessions(session_id) ON DELETE SET NULL
    )
    ''');

    //
    await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_items(
      sale_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      price_per_item INTEGER NOT NULL, -- Price at the time of sale for historical accuracy
      last_modified TEXT NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales(sale_id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT
    )
    ''');

    // phone_numbers table stores phone numbers for players
    await db.execute('''
      CREATE TABLE IF NOT EXISTS phone_numbers(
        player_id TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    // prices table stores the prices for different time slices
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prices(
        time_slice TEXT PRIMARY KEY,
        price INTEGER NOT NULL,
        last_modified TEXT NOT NULL
      )
    ''');

    // Insert default prices if they do not exist, with last_modified for NOT NULL constraint
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      INSERT OR REPLACE INTO prices (time_slice, price, last_modified) VALUES
      ('hour', 0, ?),
      ('half_hour', 0, ?),
      ('additional_hour', 0, ?),
      ('additional_half_hour', 0, ?)
    ''', [nowIso, nowIso, nowIso, nowIso]);

    // Products
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products(
        product_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        quantity_available INTEGER NOT NULL,
        last_modified TEXT NOT NULL
      )
    ''');

    // insert water and socks products
    await db.execute('''
      INSERT OR IGNORE INTO products (name, price, quantity_available, last_modified) VALUES
      ('Water Bottle', 5000, 50, ?),
      ('Socks', 35000, 100, ?)
    ''', [nowIso, nowIso]);
  }

  // get the current players
  Future<List<Player>> getCurrentPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT ps.player_id AS id,
            p.name,
            p.age,
            ps.check_in_time,
            ps.time_reserved_hours,
            ps.time_reserved_minutes,
            ps.is_open_time,
            ps.session_id,
            ps.initial_fee,
            ps.prepaid_amount AS amount_paid
    FROM player_sessions ps
    JOIN players p ON ps.player_id = p.id
    WHERE ps.check_out_time IS NULL
    ORDER BY ps.check_in_time ASC
  ''');

    return result.map((map) => Player.fromMap(map)).toList();
  }

  // Check out a player by session ID
  Future<void> checkOutPlayer(
      {required int sessionID,
      required int finalFee,
      required int amountPaid,
      required int tips}) async {
    final db = await database;
    await db.transaction((txn) async {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // set check_out_time to check out player
      await txn.update('player_sessions',
          {'check_out_time': nowIso, 'last_modified': nowIso},
          where: 'session_id = ?', whereArgs: [sessionID]);

      // create a final sales record
      await txn.insert(
        'sales',
        {
          'session_id': sessionID,
          'final_fee': finalFee,
          'amount_paid': amountPaid,
          'tips': tips,
          'sale_time': nowIso,
          'last_modified': nowIso,
        },
      );
    });
  }

  // Check in a player
  Future<void> checkInPlayer({
    String? existingPlayerID,
    required String name,
    required int age,
    required int timeReservedHours,
    required int timeReservedMinutes,
    required bool isOpenTime,
    required int initialFee,
    required int amountPaid,
    List<String> phoneNumbers = const [],
  }) async {
    // Generate a unique player ID
    var uuid = Uuid();
    final String playerID = existingPlayerID ?? uuid.v4();

    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Make all DB operations atomic using a transaction
    await db.transaction((txn) async {
      // ---- Player Session Insertion ----
      await txn.insert(
        'player_sessions',
        {
          'player_id': playerID,
          'check_in_time': nowIso,
          'time_reserved_hours': timeReservedHours,
          'time_reserved_minutes': timeReservedMinutes,
          'is_open_time': isOpenTime ? 1 : 0,
          'initial_fee': initialFee,
          'prepaid_amount': amountPaid,
          'last_modified': nowIso,
        },
      );

      // ---- Player Table Insertion ----
      if (existingPlayerID == null) {
        await txn.insert(
          'players',
          {
            'id': playerID,
            'name': name,
            'age': age,
            'last_modified': nowIso,
          },
        );
      } else {
        // TODO: Handle updating existing player info
      }

      // Insert phone numbers if any
      if (phoneNumbers.isNotEmpty) {
        // delete existing phone numbers
        await txn.delete(
          'phone_numbers',
          where: 'player_id = ?',
          whereArgs: [playerID],
        );

        for (var phoneNumber in phoneNumbers) {
          await txn.insert(
            'phone_numbers',
            {
              'player_id': playerID,
              'phone_number': phoneNumber,
              'last_modified': nowIso,
            },
          );
        }
      }
    });
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

  Future<void> updatePrices(Map<TimeSlice, int> newPrices) async {
    final db = await database;
    if (newPrices.isEmpty) return;
    if (!newPrices.containsKey(TimeSlice.hour) ||
        !newPrices.containsKey(TimeSlice.halfHour) ||
        !newPrices.containsKey(TimeSlice.additionalHour) ||
        !newPrices.containsKey(TimeSlice.additionalHalfHour)) {
      throw Exception('All time slices must be provided');
    }

    await db.rawQuery('''
      UPDATE prices
      SET price = CASE time_slice
        WHEN 'hour' THEN ?
        WHEN 'half_hour' THEN ?
        WHEN 'additional_hour' THEN ?
        WHEN 'additional_half_hour' THEN ?
      END,
      last_modified = ?
      ''', [
      newPrices[TimeSlice.hour],
      newPrices[TimeSlice.halfHour],
      newPrices[TimeSlice.additionalHour],
      newPrices[TimeSlice.additionalHalfHour],
      DateTime.now().toUtc().toIso8601String(),
    ]);
  }

  Future<List<Player>> getPastPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT id, name, age
      FROM players
      ORDER BY last_modified DESC''');

    return result
        .map((map) => Player(
              playerID: map['id'] as String,
              name: map['name'] as String,
              age: map['age'] as int,
              // Placeholders, not used in past players
              checkInTime: DateTime.now(),
              timeReserved: Duration.zero,
              amountPaid: 0,
              sessionID: 0,
              isOpenTime: false,
              initialFee: 0,
            ))
        .toList();
  }

  Future<List<String>> getPhoneNumbers(String playerId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT phone_number
      FROM phone_numbers
      WHERE player_id = ?
    ''', [playerId]);

    return result.map((map) => map['phone_number'] as String).toList();
  }

  // ------- TEST FUNCTIONS -------

  Future<void> clearDb() async {
    final db = await database;
    await db.execute('DELETE FROM players');
    await db.execute('DELETE FROM player_sessions');
    await db.execute('DELETE FROM sales');
    await db.execute('DELETE FROM sale_items');
    await db.execute('DELETE FROM phone_numbers');
    await db.execute('DELETE FROM products');
  }

  // ------- END TEST FUNCTIONS -------

  Future<List<Product>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      orderBy: 'name ASC',
    );
    if (maps.isEmpty) {
      return [];
    }
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  // Add a new product to the database
  Future<int> addProduct({
    required String name,
    required int price,
    required int quantityAvailable,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    return await db.insert(
      'products',
      {
        'name': name,
        'price': price,
        'quantity_available': quantityAvailable,
        'last_modified': nowIso,
      },
    );
  }

  // Update an existing product's quantity or price
  Future<int> updateProduct({
    required int productId,
    String? name,
    int? price,
    int? quantityAvailable,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final Map<String, dynamic> updates = {'last_modified': nowIso};
    if (name != null) updates['name'] = name;
    if (price != null) updates['price'] = price;
    if (quantityAvailable != null) {
      updates['quantity_available'] = quantityAvailable;
    }

    return await db.update(
      'products',
      updates,
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> deleteProduct(int productId) async {
    final db = await database;
    await db.delete(
      'products',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  // Purchase one or more products in a single transaction.
  Future<void> recordSeparatePurchase({required Map<Product, int> cart}) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final db = await database;

    cart.removeWhere((Product product, quantity) =>
        quantity <= 0 || product.quantityAvailable < quantity);

    if (cart.isEmpty) {
      throw Exception('Cart is empty or all products have insufficient stock.');
    }

    await db.transaction((txn) async {
      int finalFee = 0;
      for (var entry in cart.entries) {
        // calc final fee
        final Product product = entry.key;
        final int quantity = entry.value;
        finalFee += product.price * quantity;

        // Update product quantity in stock
        // update the product quantity
        await txn.update(
          'products',
          {
            'quantity_available': product.quantityAvailable - quantity,
            'last_modified': nowIso
          },
          where: 'product_id = ?',
          whereArgs: [product.id],
        );
      }

      // insert into sales
      final int saleId = await txn.insert('sales', {
        'session_id': null,
        'final_fee': finalFee,
        'amount_paid': finalFee,
        'tips': 0,
        'sale_time': nowIso,
        'last_modified': nowIso
      });

      // insert into sale_items
      for (var entry in cart.entries) {
        final Product product = entry.key;
        final int quantity = entry.value;

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': product.id,
          'quantity': quantity,
          'price_per_item': product.price,
          'last_modified': nowIso,
        });
      }
    });
  }
}
