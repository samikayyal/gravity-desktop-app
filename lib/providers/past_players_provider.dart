import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/models/session.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';

final pastPlayersProvider =
    StateNotifierProvider<PastPlayersNotifier, AsyncValue<List<Player>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return PastPlayersNotifier(dbHelper);
});

class PastPlayersNotifier extends StateNotifier<AsyncValue<List<Player>>> {
  final DatabaseHelper _dbHelper;

  PastPlayersNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    _fetchPastPlayers();
  }

  Future<void> _fetchPastPlayers() async {
    state = const AsyncValue.loading();
    try {
      final players = await _dbHelper.getPastPlayers();
      state = AsyncValue.data(players);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _fetchPastPlayers();
  }

  Future<List<PlayerPhone>> getPhoneNumbers(String playerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT phone_number, is_primary
      FROM phone_numbers
      WHERE player_id = ?
      AND is_deleted = 0
    ''', [playerId]);

    return result.map((map) => PlayerPhone.fromMap(map)).toList();
  }

  Future<void> editPlayer(
      {required String playerID,
      required String name,
      required int age,
      required List<String> phones}) async {
    state = const AsyncValue.loading();
    try {
      await _dbHelper.editPlayer(
        playerID: playerID,
        name: name,
        age: age,
        phones: phones,
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Player> getPlayerById(String playerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'players',
      where: 'id = ?',
      whereArgs: [playerId],
    );

    if (result.isEmpty) {
      throw Exception('Player not found');
    }

    return Player(
      name: result[0]['name'] as String,
      age: result[0]['age'] as int,
      playerID: result[0]['id'] as String,
      checkInTime: DateTime.now(),
      timeReserved: Duration.zero,
      amountPaid: 0,
      initialFee: 0,
      isOpenTime: false,
      sessionID: 0,
      subscriptionId: null,
    );
  }
}

final pastSessionsProvider =
    FutureProvider.family<List<Session>, String>((ref, playerId) async {
  final db = await ref.watch(databaseProvider).database;

  final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT p.*, s.session_id, s.check_in_time, s.check_out_time,
           sa.final_fee, sa.amount_paid, sr.minutes_used, sr.subscription_id
    FROM players p
    JOIN player_sessions s ON p.id = s.player_id
    JOIN sales sa ON s.session_id = sa.session_id
    LEFT JOIN subscription_records sr ON s.session_id = sr.session_id
    WHERE p.id = ?
    ORDER BY s.check_in_time DESC
    ''', [playerId]);

  return result.map((map) => Session.fromMap(map)).toList();
});

class PlayerPhone {
  final String number;
  final bool isPrimary;

  PlayerPhone({required this.number, this.isPrimary = false});

  PlayerPhone.fromMap(Map<String, dynamic> map)
      : number = map['phone_number'] as String,
        isPrimary = map['is_primary'] == 1;

  @override
  String toString() => number;
}

final playerPhonesProvider =
    FutureProvider.family<List<PlayerPhone>, String>((ref, playerId) async {
  final notifier = ref.watch(pastPlayersProvider.notifier);
  final phoneNumbers = await notifier.getPhoneNumbers(playerId);
  return phoneNumbers;
});
