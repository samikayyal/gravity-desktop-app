import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';

final subscriptionsProvider = StateNotifierProvider<SubscriptionsNotifier,
    AsyncValue<List<Subscription>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return SubscriptionsNotifier(dbHelper);
});

class SubscriptionsNotifier
    extends StateNotifier<AsyncValue<List<Subscription>>> {
  final DatabaseHelper _dbHelper;

  SubscriptionsNotifier(this._dbHelper) : super(const AsyncValue.loading()) {
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    state = const AsyncValue.loading();
    try {
      final subscriptions = await _dbHelper.getSubscriptions();
      state = AsyncValue.data(subscriptions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _fetchSubscriptions();
  }

  Future<void> addNewSubscription({
    String? existingPlayerId,
    required String playerName,
    required int age,
    required List<String> phoneNumbers,
    required int hoursIncluded,
    required int durationMinutes,
    required int discountPercent,
    required int totalFee,
    required int amountPaid,
  }) async {
    await _dbHelper.addNewSubscription(
      existingPlayerId: existingPlayerId,
      playerName: playerName,
      age: age,
      phoneNumbers: phoneNumbers,
      hoursIncluded: hoursIncluded,
      durationMinutes: durationMinutes,
      discountPercent: discountPercent,
      totalFee: totalFee,
      amountPaid: amountPaid,
    );
    await refresh();
  }
}
