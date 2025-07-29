import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'create_test_container.dart';

void main() {
  // Initialize sqflite_ffi for testing ONCE before all tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group(
    'checkInPlayer Tests',
    () {
      test(
          "checkInPlayer adds a NEW player correctly to the db and updates the state",
          () async {
        final (container, db) = await createTestContainer();
        // Wait for the initial empty state
        await Future.microtask(() {});
        final notifier = container.read(currentPlayersProvider.notifier);

        // Act: Check in a new player
        await notifier.checkInPlayer(
          name: 'Test Player',
          age: 25,
          timeReservedMinutes: 60,
          isOpenTime: false,
          totalFee: 95000,
          amountPaid: 95000,
          phoneNumbers: ['0992606148'],
        );

        // Assert: Data should be saved in the database correctly
        // first the players table, since new player, new record should be inserted
        final playersTableQuery = await db.query('players');
        expect(playersTableQuery.length, 1);
        expect(playersTableQuery.first['name'], 'Test Player');
        expect(playersTableQuery.first['age'], 25);

        // Get the player id
        final String playerId = playersTableQuery.first['id'] as String;

        // Now check the player_sessions table
        final playerSessionsTableQuery = await db.query('player_sessions');
        final psRecord = playerSessionsTableQuery.first;

        expect(playerSessionsTableQuery.length, 1);
        expect(psRecord['player_id'] as String, playerId);
        expect(psRecord['time_reserved_minutes'] as int, 60);
        expect(psRecord['is_open_time'] as int, 0);
        expect(psRecord['time_extended_minutes'] as int, 0);
        expect(psRecord['check_out_time'], isNull);
        expect(psRecord['initial_fee'] as int, 95000);
        expect(psRecord['prepaid_amount'] as int, 95000);
        expect(psRecord['group_number'], isNull);

        // phone numbers table
        final phoneQuery = await db.query('phone_numbers');
        expect(phoneQuery.length, 1);
        expect(phoneQuery.first['player_id'] as String, playerId);
        expect(phoneQuery.first['phone_number'], '0992606148');
        expect(phoneQuery.first['is_primary'], 1);
        expect(phoneQuery.first['is_deleted'], 0);

        // Assert: The state should now contain one player
        final players = container.read(currentPlayersProvider).value;
        expect(players, isNotNull);
        expect(players!.length, 1);
        expect(players.first.name, 'Test Player');
        expect(players.first.age, 25);
        expect(players.first.amountPaid, 95000);
        expect(players.first.initialFee, 95000);
        expect(players.first.playerID, playerId);
        expect(players.first.isOpenTime, false);
        expect(players.first.timeReserved, Duration(minutes: 60));
        expect(players.first.timeExtended, Duration.zero);
      });

      test("checkInPlayer adds an Existing player correctly to the db",
          () async {
        final (container, db) = await createTestContainer();
        // Wait for the initial empty state
        await Future.microtask(() {});
        final notifier = container.read(currentPlayersProvider.notifier);

        // first add the existing player to the players table
        var uuid = Uuid();
        final playerId = uuid.v4();
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await db.insert('players', {
          'id': playerId,
          'name': 'Existing Player',
          'age': 30,
          'last_modified': nowIso
        });

        // check in the player
        await notifier.checkInPlayer(
          name: 'Existing Player',
          age: 30,
          existingPlayerID: playerId,
          timeReservedMinutes: 60,
          totalFee: 95000,
          amountPaid: 95000,
          isOpenTime: false,
          phoneNumbers: ['0992606148', '099999999'],
        );

        // Assert: Data should be saved in the database correctly
        // first the players table, no new player should be added
        final playersTableQuery = await db.query('players');
        expect(playersTableQuery.length, 1);
        expect(playersTableQuery.first['name'], 'Existing Player');
        expect(playersTableQuery.first['age'], 30);
        expect(playersTableQuery.first['id'], playerId);

        // Now check the player_sessions table
        final playerSessionsTableQuery = await db.query('player_sessions');
        final psRecord = playerSessionsTableQuery.first;

        expect(playerSessionsTableQuery.length, 1);
        expect(psRecord['player_id'] as String, playerId);
        expect(psRecord['time_reserved_minutes'] as int, 60);
        expect(psRecord['is_open_time'] as int, 0);
        expect(psRecord['time_extended_minutes'] as int, 0);
        expect(psRecord['check_out_time'], isNull);
        expect(psRecord['initial_fee'] as int, 95000);
        expect(psRecord['prepaid_amount'] as int, 95000);
        expect(psRecord['group_number'], isNull);

        // phone numbers table
        final phoneQuery =
            await db.query('phone_numbers', orderBy: 'is_primary DESC');
        // the primary one will be first
        expect(phoneQuery.length, 2);
        final primaryRow = phoneQuery.first;
        final otherRow = phoneQuery[1];
        expect(primaryRow['player_id'] as String, playerId);
        expect(otherRow['player_id'] as String, playerId);

        expect(primaryRow['phone_number'], '0992606148');
        expect(primaryRow['is_primary'], 1);
        expect(primaryRow['is_deleted'], 0);

        expect(otherRow['phone_number'], '099999999');
        expect(otherRow['is_primary'], 0);
        expect(otherRow['is_deleted'], 0);

        // Assert: The state should now contain one player
        final players = container.read(currentPlayersProvider).value;
        expect(players, isNotNull);
        expect(players!.length, 1);
        expect(players.first.name, 'Existing Player');
        expect(players.first.age, 30);
        expect(players.first.amountPaid, 95000);
        expect(players.first.initialFee, 95000);
        expect(players.first.playerID, playerId);
        expect(players.first.isOpenTime, false);
        expect(players.first.timeReserved, Duration(minutes: 60));
        expect(players.first.timeExtended, Duration.zero);
      });

      test("checkInPlayer handles subscribers correctly", () async {
        final (container, db) = await createTestContainer();
        // Wait for the initial empty state
        await Future.microtask(() {});
        final notifier = container.read(currentPlayersProvider.notifier);
        // first insert the subscriber
        var uuid = Uuid();
        final String playerId = uuid.v4();
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await db.insert('subscriptions', {
          'subscription_id': 1,
          'player_id': playerId,
          'start_date': nowIso,
          'expiry_date':
              DateTime.now().add(Duration(days: 30)).toUtc().toIso8601String(),
          'discount_percent': 45,
          'total_minutes': 10 * 60, // 10 hours
          'remaining_minutes': 10 * 60,
          'status': 'active',
          'total_fee': 530000,
          'amount_paid': 500000,
          'last_modified': nowIso
        });

        // add him to players table
        await db.insert('players', {
          'id': playerId,
          'name': 'Subscriber Guy',
          'age': 12,
          'last_modified': nowIso
        });

        // check him in
        await notifier.checkInPlayer(
          name: 'Subscriber Guy',
          age: 12,
          existingPlayerID: playerId,
          timeReservedMinutes: 30,
          totalFee: 75000,
          amountPaid: 75000,
          isOpenTime: false,
          // phoneNumbers: ['0992606148', '099999999'],
        );

        // Assert: Data should be saved in the database correctly
        // first the players table, no new player should be added
        final playersTableQuery = await db.query('players');
        expect(playersTableQuery.length, 1);
        expect(playersTableQuery.first['name'], 'Subscriber Guy');
        expect(playersTableQuery.first['age'], 12);
        expect(playersTableQuery.first['id'], playerId);

        // Now check the player_sessions table
        final playerSessionsTableQuery = await db.query('player_sessions');
        final psRecord = playerSessionsTableQuery.first;

        expect(playerSessionsTableQuery.length, 1);
        expect(psRecord['player_id'] as String, playerId);
        expect(psRecord['time_reserved_minutes'] as int, 30);
        expect(psRecord['is_open_time'] as int, 0);
        expect(psRecord['time_extended_minutes'] as int, 0);
        expect(psRecord['check_out_time'], isNull);
        expect(psRecord['initial_fee'] as int, 75000);
        expect(psRecord['prepaid_amount'] as int, 75000);
        expect(psRecord['group_number'], isNull);

        // Assert: The state should now contain one player
        final players = container.read(currentPlayersProvider).value;
        expect(players, isNotNull);
        expect(players!.length, 1);
        expect(players.first.name, 'Subscriber Guy');
        expect(players.first.age, 12);
        expect(players.first.amountPaid, 75000);
        expect(players.first.initialFee, 75000);
        expect(players.first.playerID, playerId);
        expect(players.first.isOpenTime, false);
        expect(players.first.timeReserved, Duration(minutes: 30));
        expect(players.first.timeExtended, Duration.zero);
      });

      test("checkInPlayer handles products correctly", () async {
        final (container, db) = await createTestContainer();
        // Wait for the initial empty state
        await Future.microtask(() {});
        final notifier = container.read(currentPlayersProvider.notifier);

        // first add the products to the db
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await db.insert('products', {
          'name': 'Product A',
          'price': 10000,
          'quantity_available': 100,
          'last_modified': nowIso,
        });

        await db.insert('products', {
          'name': 'Product B',
          'price': 25000,
          'quantity_available': 100,
          'last_modified': nowIso,
        });

        // check in a player with products
        final productsBought = {3: 2, 4: 3};
        await notifier.checkInPlayer(
          name: 'Test Player ',
          age: 6,
          timeReservedMinutes: 30,
          isOpenTime: false,
          totalFee: 75000 + 95000, // half hour + products fee
          amountPaid: 75000 + 95000,
          productsBought: productsBought,
        );

        // Get the session id
        final int sessionId =
            (await db.query('player_sessions')).first['session_id'] as int;

        // Assert: The session_products table should include these products
        final query = await db.query('session_products');

        expect(query.length, 2);
        final productA = query.first;
        final productB = query.last;

        expect(productA['session_id'] as int, sessionId);
        expect(productB['session_id'] as int, sessionId);

        expect(productA['product_id'] as int, 3);
        expect(productB['product_id'] as int, 4);

        expect(productA['quantity'] as int, 2);
        expect(productB['quantity'] as int, 3);
      });
    },
  );
}
