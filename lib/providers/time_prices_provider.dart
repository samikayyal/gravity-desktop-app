import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/providers/database_provider.dart';

final pricesProvider =
    StateNotifierProvider<TimePricesNotifier, AsyncValue<Map<TimeSlice, int>>>(
        (ref) {
  final dbHelper = ref.watch(databaseProvider);
  return TimePricesNotifier(dbHelper);
});

class TimePricesNotifier
    extends StateNotifier<AsyncValue<Map<TimeSlice, int>>> {
  final DatabaseHelper _db;

  TimePricesNotifier(this._db) : super(const AsyncValue.loading()) {
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    state = const AsyncValue.loading();
    try {
      final prices = await _db.getPrices();
      state = AsyncValue.data(prices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _fetchPrices();
  }
}
