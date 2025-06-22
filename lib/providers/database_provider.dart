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

  Future<void> checkOutPlayer(int sessionId) async {
    await _dbHelper
        .checkOutPlayer(sessionId); // Assuming you create this method
    await refresh(); // Refresh the list to remove the player from the UI
  }

  // check in a player
  Future<void> checkInPlayer({
    String? existingPlayerID,
    required String name,
    required int age,
    required int timeReservedHours,
    required int timeReservedMinutes,
    required bool isOpenTime,
    required int totalFee,
    required int amountPaid,
    List<String> phoneNumbers = const [],
  }) async {
    await _dbHelper.checkInPlayer(
        existingPlayerID: existingPlayerID,
        name: name,
        age: age,
        timeReservedHours: timeReservedHours,
        timeReservedMinutes: timeReservedMinutes,
        isOpenTime: isOpenTime,
        totalFee: totalFee,
        amountPaid: amountPaid,
        phoneNumbers: phoneNumbers);
    await refresh();
  }
}

// Provider for time slice prices
final pricesProvider = FutureProvider<Map<TimeSlice, int>>((ref) async {
  final dbHelper = ref.watch(databaseProvider);
  return dbHelper.getPrices();
});
