// ignore: unused_import
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/screens/add_group.dart';
import 'package:uuid/uuid.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

// use StateNotifierProvider for a list that can be updated.
final currentPlayersProvider =
    StateNotifierProvider<CurrentPlayersNotifier, AsyncValue<List<Player>>>(
        (ref) {
  final dbHelper = ref.watch(databaseProvider);
  return CurrentPlayersNotifier(dbHelper);
});

// The Notifier class that will hold and manage our state.
class CurrentPlayersNotifier extends StateNotifier<AsyncValue<List<Player>>> {
  final DatabaseHelper _dbHelper;

  CurrentPlayersNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    _fetchCurrentPlayers(); // Fetch initial data when the provider is first created
  }

  // Fetch data from the database and update the state
  Future<void> _fetchCurrentPlayers() async {
    state = const AsyncValue.loading();
    try {
      final players = await _dbHelper.getCurrentPlayers();
      state = AsyncValue.data(players);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Call this method after adding a new player session to refresh the list
  Future<void> refresh() async {
    await _fetchCurrentPlayers();
  }

  Future<void> checkOutPlayer({
    required int sessionID,
    required int finalFee,
    required int amountPaid,
    required int tips,
    required String checkoutTime,
    int? discount,
    String? discountReason,
  }) async {
    await _dbHelper.checkOutPlayer(
      sessionID: sessionID,
      finalFee: finalFee,
      amountPaid: amountPaid,
      tips: tips,
      discount: discount,
      discountReason: discountReason,
      checkoutTime: checkoutTime,
    );
    await refresh();
  }

  // check in a player
  Future<void> checkInPlayer({
    String? existingPlayerID,
    required String name,
    required int age,
    required int timeReservedMinutes,
    required bool isOpenTime,
    required int totalFee,
    required int amountPaid,
    List<String> phoneNumbers = const [],
    int? subscriptionId,
    Map<int, int> productsBought = const {},
  }) async {
    await _dbHelper.checkInPlayer(
      existingPlayerID: existingPlayerID,
      name: name,
      age: age,
      timeReservedMinutes: timeReservedMinutes,
      isOpenTime: isOpenTime,
      initialFee: totalFee,
      amountPaid: amountPaid,
      phoneNumbers: phoneNumbers,
      subscriptionId: subscriptionId,
      productsBought: productsBought,
    );
    await refresh();
  }

  // -------- TEST SECTION --------
  Future<void> clearCurrentPlayers() async {
    await _dbHelper.clearDb();
    await refresh();
  }
  // -------- END TEST --------

  Future<void> extendPlayerTime(Player player,
      {required Duration timeToExtend, required bool isOpenTime}) async {
    final db = await _dbHelper.database;
    await db.update('player_sessions', {
      'time_reserved_minutes':
          player.timeReserved.inMinutes + timeToExtend.inMinutes,
      'is_open_time': isOpenTime ? 1 : 0,
    });
    await refresh();
  }

  Future<Player> currentPlayerSession(int sessionId) async {
    final db = await _dbHelper.database;

    try {
      final List<Map<String, dynamic>> query = await db.rawQuery(
        '''SELECT ps.player_id AS id, p.name AS name, p.age AS age,
                ps.check_in_time AS check_in_time,
                ps.time_reserved_minutes AS time_reserved_minutes,
                ps.is_open_time AS is_open_time,
                ps.prepaid_amount AS amount_paid,
                ps.initial_fee AS initial_fee,
                ps.group_number AS group_number,
                ps.session_id AS session_id,
                s.subscription_id AS subscription_id
         FROM player_sessions ps
         JOIN players p ON ps.player_id = p.id
         LEFT JOIN subscriptions s ON ps.player_id = s.player_id
         WHERE ps.session_id = ?''',
        [sessionId],
      );

      if (query.isEmpty) {
        throw Exception('No player session found with id $sessionId');
      }
      Player player = Player.fromMap(query.first);

      // Fetch products bought in this session
      final productsBought = await db.query(
        'session_products',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      if (productsBought.isNotEmpty) {
        for (var product in productsBought) {
          int productId = product['product_id'] as int;
          int quantity = product['quantity'] as int;
          player.addProduct(productId, quantity);
        }
      }

      return player;
    } catch (e, st) {
      log('Error fetching player session: $e\n$st');
      throw Exception('Error fetching player session: $e');
    }
  }

  Future<void> checkInGroup(
      {required List<GroupPlayer> groupPlayers,
      required int timeReservedMinutes,
      required bool isOpenTime,
      required int amountPaid,
      List<String> phoneNumbers = const []}) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // get a group number
      final List<Map<String, dynamic>> groupNumberQuery = await txn.rawQuery(
        'SELECT group_number AS group_number FROM player_sessions WHERE check_out_time IS NULL',
      );

      // get a group number not in use
      int groupNumber = 1;
      if (groupNumberQuery.isNotEmpty) {
        final existingGroupNumbers = groupNumberQuery
            .map((e) => e['group_number'] as int?) // Use int? for safety
            .where((number) => number != null) // Filter out any nulls
            .toSet();

        // Keep incrementing the group number as long as it's already taken
        while (existingGroupNumbers.contains(groupNumber)) {
          groupNumber++;
        }
      }

      for (GroupPlayer player in groupPlayers) {
        // generate an id if it doesnt exist
        var uuid = Uuid();
        final String playerId = player.existingPlayer?.playerID ?? uuid.v4();

        // get player fee
        int playerInitialFee = player.getFee(timeReservedMinutes, isOpenTime);

        // if a new player add to db
        if (player.existingPlayer == null) {
          await txn.insert(
            'players',
            {
              'id': playerId,
              'name': player.fullName,
              'age': player.age,
              'last_modified': nowIso,
            },
          );
        }

        // insert the player session
        final int sessionId = await txn.insert(
          'player_sessions',
          {
            'player_id': playerId,
            'check_in_time': nowIso,
            'time_reserved_minutes': timeReservedMinutes,
            'is_open_time': isOpenTime ? 1 : 0,
            'initial_fee': playerInitialFee,
            'prepaid_amount': amountPaid ~/ groupPlayers.length,
            'group_number': groupNumber,
            'last_modified': nowIso,
          },
        );

        // insert phone numbers if any
        if (phoneNumbers.isNotEmpty) {
          // delete existing phone numbers
          await txn.update(
            'phone_numbers',
            {'is_deleted': 1},
            where: 'player_id = ?',
            whereArgs: [playerId],
          );

          for (var phoneNumber in phoneNumbers) {
            await txn.insert(
              'phone_numbers',
              {
                'player_id': playerId,
                'phone_number': phoneNumber,
                'is_primary': phoneNumber == phoneNumbers.first ? 1 : 0,
                'last_modified': nowIso,
              },
            );
          }
        }

        // Products
        for (var entry in player.productsCart.entries) {
          await txn.insert('session_products', {
            'session_id': sessionId,
            'product_id': entry.key,
            'quantity': entry.value,
            'last_modified': nowIso,
          });
        }
      }
    });
    await refresh();
  }
}
