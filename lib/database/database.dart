import 'dart:developer';

import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/product.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
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
      time_reserved_minutes INTEGER NOT NULL,
      is_open_time INTEGER NOT NULL,     -- 0 for false, 1 for true
      check_out_time TEXT,               -- *** NULL means this session is ACTIVE ***

      -- payment info
      initial_fee INTEGER NOT NULL DEFAULT 0,
      prepaid_amount INTEGER NOT NULL DEFAULT 0,
      group_number INTEGER, -- for grouping players in a session
      last_modified TEXT NOT NULL,       
      FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE SET NULL
    )
    ''');

    /// For sub payments sub id will be given, and final fee will be a fixed fee
    /// of the sub final fee.
    await db.execute('''
    CREATE TABLE IF NOT EXISTS sales(
      sale_id INTEGER PRIMARY KEY AUTOINCREMENT,
      subscription_id INTEGER, -- NULL if not a subscriber
      session_id INTEGER,               -- NULL if it's a separate (e.g. walk-in) purchase
      final_fee INTEGER NOT NULL,    -- Total value of the sale (session fee + products)
      amount_paid INTEGER NOT NULL,
      tips INTEGER NOT NULL DEFAULT 0,
      sale_time TEXT NOT NULL,
      discount INTEGER DEFAULT 0,
      discount_reason TEXT,
      last_modified TEXT NOT NULL,
      FOREIGN KEY (session_id) REFERENCES player_sessions(session_id) ON DELETE SET NULL,
      FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id) ON DELETE SET NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS sale_items(
      sale_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      price_per_item INTEGER NOT NULL, -- Price at the time of sale for historical accuracy
      last_modified TEXT NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales(sale_id) ON DELETE SET NULL,
      FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE SET NULL
    )
    ''');

    // phone_numbers table stores phone numbers for players
    await db.execute('''
      CREATE TABLE IF NOT EXISTS phone_numbers(
        player_id TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        is_primary INTEGER NOT NULL, -- 0 for false, 1 for true
        is_deleted INTEGER NOT NULL DEFAULT 0, -- 0 for not deleted, 1 for deleted
        last_modified TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE SET NULL
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

    // Insert default prices if they do not exist
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      INSERT OR REPLACE INTO prices (time_slice, price, last_modified) VALUES
      ('hour', 95000, ?),
      ('half_hour', 75000, ?),
      ('additional_hour', 70000, ?),
      ('additional_half_hour', 45000, ?)
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
      ('Water Bottle', 7000, 50, ?),
      ('Socks', 25000, 100, ?)
    ''', [nowIso, nowIso]);

    // Table to store products bought in a session
    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_products(
        session_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        last_modified TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES player_sessions(session_id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
        PRIMARY KEY (session_id, product_id)
      )''');

    // Subscriptions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscriptions(
        subscription_id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id TEXT NOT NULL,
        start_date TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        discount_percent INTEGER NOT NULL,
        total_minutes INTEGER NOT NULL,
        remaining_minutes INTEGER NOT NULL,
        status TEXT NOT NULL, -- 'active', 'expired', 'paused', 'deleted'
        total_fee INTEGER NOT NULL,
        amount_paid INTEGER NOT NULL,
        last_modified TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE SET NULL,
        CHECK (status IN ('active', 'expired', 'paused', 'finished'))
      )
      ''');

    // Subscription records
    await db.execute('''
      CREATE TABLE IF NOT EXISTS subscription_records(
        record_id INTEGER PRIMARY KEY AUTOINCREMENT,
        subscription_id INTEGER NOT NULL,
        session_id INTEGER NOT NULL,
        minutes_used INTEGER NOT NULL,
        last_modified TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES player_sessions(session_id) ON DELETE SET NULL,
        FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id) ON DELETE SET NULL
      )''');

    // notes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes(
        note_id INTEGER PRIMARY KEY AUTOINCREMENT,
        note TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0, -- 0 for not deleted, 1 for deleted,
        last_modified TEXT NOT NULL
      )
      ''');
  }

  // get the current players
  Future<List<Player>> getCurrentPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT ps.player_id AS id,
            p.name,
            p.age,
            ps.check_in_time,
            ps.time_reserved_minutes,
            ps.is_open_time,
            ps.session_id,
            ps.initial_fee,
            ps.group_number,
            ps.prepaid_amount AS amount_paid,
            sub.subscription_id
    FROM player_sessions ps
    JOIN players p ON ps.player_id = p.id
    LEFT JOIN subscriptions sub ON p.id = sub.player_id
    WHERE ps.check_out_time IS NULL
  ''');

    final List<Player> players =
        result.map((map) => Player.fromMap(map)).toList();

    // fetch products bought if any
    for (var player in players) {
      final products = await db.rawQuery('''
        SELECT p.product_id, p.name, p.price, sp.quantity
        FROM session_products sp
        JOIN products p ON sp.product_id = p.product_id
        WHERE sp.session_id = ?
      ''', [player.sessionID]);

      for (var product in products) {
        final productId = product['product_id'] as int;
        final productQuantity = product['quantity'] as int;
        player.addProduct(productId, productQuantity);
      }
    }
    // sort by time remaining
    players.sort((a, b) {
      final endTimeA = a.checkInTime.add(a.timeReserved);
      final endTimeB = b.checkInTime.add(b.timeReserved);
      return endTimeA.compareTo(endTimeB);
    });

    return players;
  }

  // Check out a player by session ID
  Future<void> checkOutPlayer(
      {required int sessionID,
      required int finalFee,
      required int amountPaid,
      required int tips,
      required String checkoutTime,
      int? discount,
      String? discountReason}) async {
    final db = await database;
    await db.transaction((txn) async {
      final nowIso = checkoutTime;

      // see if the player inside is a subscriber
      final subscriberQuery = await txn.rawQuery('''
        SELECT subscription_id, status, remaining_minutes
        FROM subscriptions
        WHERE player_id = (
          SELECT player_id
          FROM player_sessions
          WHERE session_id = ?
        )''', [sessionID]);

      late final bool isSub;
      late final Map<String, dynamic>? sub;
      if (subscriberQuery.isEmpty) {
        isSub = false;
      } else {
        sub = subscriberQuery.first;
        isSub = sub['subscription_id'] != null && sub['status'] == 'active';
      }
      log("isSub in checkout: $isSub");

      // set check_out_time to check out player
      await txn.update('player_sessions',
          {'check_out_time': nowIso, 'last_modified': nowIso},
          where: 'session_id = ?', whereArgs: [sessionID]);

      // create a final sales record
      final saleId = await txn.insert(
        'sales',
        {
          'session_id': sessionID,
          'subscription_id':
              isSub ? subscriberQuery.first['subscription_id'] : null,
          'final_fee': finalFee,
          'amount_paid': amountPaid,
          'tips': tips,
          'sale_time': nowIso,
          'last_modified': nowIso,
          'discount': discount ?? 0,
          'discount_reason': discountReason ?? '',
        },
      );
      // Get products bought in this session
      final List<Map<String, dynamic>> productsBought = await txn.rawQuery('''
        SELECT product_id, quantity
        FROM session_products
        WHERE session_id = ?
      ''', [sessionID]);

      // If products were bought, record them in sale_items
      if (productsBought.isNotEmpty) {
        for (var entry in productsBought) {
          await txn.insert(
            'sale_items',
            {
              'sale_id': saleId,
              'product_id': entry['product_id'] as int,
              'quantity': entry['quantity'] as int,
              'price_per_item': await txn.rawQuery(
                'SELECT price FROM products WHERE product_id = ?',
                [entry['product_id'] as int],
              ).then((value) => value.first['price'] as int),
              'last_modified': nowIso,
            },
          );

          await txn.rawUpdate('''
            UPDATE products
            SET quantity_available = quantity_available - ?
            WHERE product_id = ?
          ''', [entry['quantity'], entry['product_id'] as int]);
        }
      }

      // Subscription shit
      if (isSub) {
        final timeSpentQuery = await txn.rawQuery('''
          SELECT check_in_time, check_out_time
          FROM player_sessions
          WHERE session_id = ?
          ''', [sessionID]);

        final checkInTime =
            DateTime.parse(timeSpentQuery.first['check_in_time'] as String);
        final checkOutTime =
            DateTime.parse(timeSpentQuery.first['check_out_time'] as String);

        final Duration timeSpent = checkOutTime.difference(checkInTime);

        final int halfHourBlocks = (timeSpent.inMinutes ~/ 30);
        final remainderMinutes = timeSpent.inMinutes % 30;

        int totalHalfHourBlocks = remainderMinutes > leewayMinutes
            ? halfHourBlocks + 1 // Over leeway, charge for next block
            : halfHourBlocks; // Within leeway, only charge for full blocks

        int timeToSubstract = ((totalHalfHourBlocks * 0.5) * 60).toInt();

        if (totalHalfHourBlocks == 0) {
          timeToSubstract = 30; // At least charge for half an hour
        }

        // insert to sub records
        await txn.insert('subscription_records', {
          'subscription_id': sub!['subscription_id'],
          'session_id': sessionID,
          'minutes_used': timeToSubstract,
          'last_modified': nowIso,
        });

        // update remianing time in subs table
        await txn.update(
          'subscriptions',
          {
            'remaining_minutes': sub['remaining_minutes'] - timeToSubstract,
            'last_modified': nowIso,
          },
          where: 'subscription_id = ?',
          whereArgs: [sub['subscription_id']],
        );
      }

      // Clear session products after checkout
      await txn.delete(
        'session_products',
        where: 'session_id = ?',
        whereArgs: [sessionID],
      );
    });
  }

  // Check in a player
  Future<void> checkInPlayer({
    String? existingPlayerID,
    required String name,
    required int age,
    required int timeReservedMinutes,
    required bool isOpenTime,
    required int initialFee,
    required int amountPaid,
    List<String> phoneNumbers = const [],
    int? subscriptionId,
    Map<int, int> productsBought = const {},
  }) async {
    // Generate a unique player ID
    var uuid = Uuid();
    final String playerID = existingPlayerID ?? uuid.v4();

    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Make all DB operations atomic using a transaction
    await db.transaction((txn) async {
      // ---- Player Session Insertion ----
      final sessionId = await txn.insert(
        'player_sessions',
        {
          'player_id': playerID,
          'check_in_time': nowIso,
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
        /// Handle updating existing player info happens separately
        /// This is just to ensure the player exists in the players table
      }

      // Insert phone numbers if any
      if (phoneNumbers.isNotEmpty) {
        // delete existing phone numbers
        await txn.update(
          'phone_numbers',
          {'is_deleted': 1},
          where: 'player_id = ?',
          whereArgs: [playerID],
        );

        for (var phoneNumber in phoneNumbers) {
          await txn.insert(
            'phone_numbers',
            {
              'player_id': playerID,
              'phone_number': phoneNumber,
              'is_primary': phoneNumber == phoneNumbers.first ? 1 : 0,
              'last_modified': nowIso,
            },
          );
        }
      }

      // insert session products
      if (productsBought.isNotEmpty) {
        for (var entry in productsBought.entries) {
          final productId = entry.key;
          final quantity = entry.value;

          await txn.insert('session_products', {
            'session_id': sessionId,
            'product_id': productId,
            'quantity': quantity,
            'last_modified': nowIso,
          });
        }
      }

      // --------------- SUBSCRIBER
      if (subscriptionId != null) {
        // get sub info
        final subscriptionInfo = await txn.rawQuery('''
          SELECT player_id, start_date, expiry_date, status, remaining_minutes, total_fee, amount_paid
          FROM subscriptions
          WHERE subscription_id = ?''', [subscriptionId]);

        final sub = subscriptionInfo.first;

        // Validation
        if (subscriptionInfo.isEmpty) {
          throw Exception('Subscription not found');
        }
        if (sub['status'] != 'active') {
          throw Exception(
              'Subscription is not active, its status is ${sub['status']}');
        }
        if ((sub['remaining_minutes']! as int) < timeReservedMinutes) {
          throw Exception('Not enough remaining minutes in subscription');
        }

        // NOTE: Insert into subscription_records at checkout
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
      SELECT id, name, age, s.subscription_id
      FROM players p
      LEFT JOIN subscriptions s ON p.id = s.player_id
      WHERE p.id NOT IN ( -- make sure not to include current players
        SELECT player_id FROM player_sessions WHERE check_out_time IS NULL
      )
      ORDER BY p.last_modified DESC''');

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
              subscriptionId: map['subscription_id'] as int?,
            ))
        .toList();
  }

  // ------- TEST FUNCTIONS -------

  Future<void> clearDb() async {
    final db = await database;
    await db.execute('DELETE FROM players');
    await db.execute('DELETE FROM player_sessions');
    await db.execute('DELETE FROM sales');
    await db.execute('DELETE FROM sale_items');
    await db.execute('DELETE FROM phone_numbers');
    await db.execute('DELETE FROM session_products');
    await db.execute('DELETE FROM subscriptions');
    await db.execute('DELETE FROM subscription_records');
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

    List<Product> allProducts = [];

    // get effective stock for products
    for (var product in maps) {
      final result = await db.rawQuery(
        'SELECT quantity_available FROM products WHERE product_id = ?',
        [product['product_id']],
      );

      if (result.isEmpty) {
        throw Exception('Product with ID ${product['product_id']} not found');
      }

      final int stock = result.first['quantity_available'] as int;
      final sessionProducts = await db.rawQuery(
        'SELECT SUM(quantity) AS total_quantity '
        'FROM session_products WHERE product_id = ?',
        [product['product_id']],
      );

      final int sessionQuantity = sessionProducts.isNotEmpty
          ? (sessionProducts.first['total_quantity'] as int?) ?? 0
          : 0;

      // Calculate the effective stock by subtracting session quantities from available stock
      final int effectiveStock = stock - sessionQuantity;

      allProducts.add(Product(
        id: product['product_id'] as int,
        name: product['name'] as String,
        price: product['price'] as int,
        effectiveStock: effectiveStock,
      ));
    }

    return allProducts;
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

  Future<void> updatePlayerProducts(Player player) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    log('Products bought for player ${player.playerID}: ${player.productsBought}');
    log('Session ID: ${player.sessionID}');

    // Clear existing products for this session
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM session_products WHERE session_id=?',
          [player.sessionID]);

      // Insert new products bought
      for (var entry in player.productsBought.entries) {
        final productId = entry.key;
        final quantity = entry.value;

        await txn.insert(
          'session_products',
          {
            'session_id': player.sessionID,
            'product_id': productId,
            'quantity': quantity,
            'last_modified': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Subscription>> getSubscriptions() async {
    final db = await database;
    final List<Map<String, dynamic>> subscriptionsQuery = await db.rawQuery('''
      SELECT subscriptions.*, players.name AS player_name
      FROM subscriptions
      JOIN players ON subscriptions.player_id = players.id
      WHERE subscriptions.status IN ('active', 'expired', 'paused') -- not finished
      ORDER BY subscriptions.expiry_date ASC''');

    /// Create mutable copies and add phone numbers because its normally
    /// read only which is stupid
    final List<Map<String, dynamic>> mutableSubscriptions = [];
    for (var row in subscriptionsQuery) {
      // Create a mutable copy of the row
      final Map<String, dynamic> mutableRow = Map<String, dynamic>.from(row);

      // Fetch phone numbers for this player
      final phoneNumbersResult = await db.rawQuery('''
        SELECT phone_number
        FROM phone_numbers
        WHERE player_id = ?
      ''', [row['player_id']]);

      // Extract phone numbers as a list of strings
      final phoneNumbers = phoneNumbersResult
          .map((phoneRow) => phoneRow['phone_number'] as String)
          .toList();

      mutableRow['phone_numbers'] = phoneNumbers;
      mutableSubscriptions.add(mutableRow);
    }

    return mutableSubscriptions
        .map((map) => Subscription.fromMap(map))
        .toList();
  }

  Future<void> makeSubPayment({
    required String subscriptionId,
    required int amountPaid,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // get sub total fee and amount left/prev amount paid
      final List<Map<String, dynamic>> subQuery = await txn.rawQuery('''
        SELECT total_fee, amount_paid
        FROM subscriptions
        WHERE subscription_id = ?
      ''', [subscriptionId]);

      if (subQuery.isEmpty) {
        throw Exception('Subscription not found');
      }

      await txn.insert('sales', {
        'subscription_id': subscriptionId,
        'session_id': null,
        'final_fee': subQuery.first['total_fee'],
        'amount_paid': amountPaid,
        'tips': 0,
        'last_modified': nowIso,
      });

      // Update the subscription's amount_paid and status
      await txn.update(
          'subscriptions',
          {
            'amount_paid': amountPaid +
                (subQuery.first['amount_paid']
                    as int), // add to prev amount paid
            'last_modified': nowIso,
          },
          where: 'id = ?',
          whereArgs: [subscriptionId]);
    });
  }

  Future<void> editPlayer(
      {required String playerID,
      required String name,
      required int age,
      required List<String> phones}) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // Update player info
      await txn.update(
        'players',
        {'name': name, 'age': age, 'last_modified': nowIso},
        where: 'id = ?',
        whereArgs: [playerID],
      );

      // Update phone numbers
      if (phones.isNotEmpty) {
        // delete existing phone numbers
        await txn.update(
          'phone_numbers',
          {'is_deleted': 1},
          where: 'player_id = ?',
          whereArgs: [playerID],
        );

        for (var phoneNumber in phones) {
          await txn.insert(
            'phone_numbers',
            {
              'player_id': playerID,
              'phone_number': phoneNumber,
              'is_primary': phoneNumber == phones.first ? 1 : 0,
              'last_modified': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
