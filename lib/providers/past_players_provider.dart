import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/player.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';

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
}
