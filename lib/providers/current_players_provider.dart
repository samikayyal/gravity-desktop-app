import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/player.dart';

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
      print('Error fetching player session: $e\n$st');
      throw Exception('Error fetching player session: $e');
    }
  }
}
