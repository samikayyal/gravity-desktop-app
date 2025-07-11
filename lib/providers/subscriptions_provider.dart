import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/subscription.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

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
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    state = const AsyncValue.loading();

    try {
      await db.transaction((txn) async {
        final String playerId = existingPlayerId ?? Uuid().v4();
        if (existingPlayerId == null) {
          await txn.insert(
            'players',
            {
              'id': playerId,
              'name': playerName,
              'age': age,
              'last_modified': nowIso,
            },
          );
        }

        if (phoneNumbers.isNotEmpty) {
          for (var phoneNumber in phoneNumbers) {
            await txn.insert(
              'phone_numbers',
              {
                'player_id': playerId,
                'phone_number': phoneNumber,
                'is_primary': phoneNumber == phoneNumbers.first ? 1 : 0,
                'last_modified': nowIso,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        final subscriptionId = await txn.insert(
          'subscriptions',
          {
            'player_id': playerId,
            'start_date': nowIso,
            'expiry_date': DateTime.now()
                .add(Duration(minutes: durationMinutes))
                .toUtc()
                .toIso8601String(),
            'discount_percent': discountPercent,
            'total_minutes': hoursIncluded * 60,
            'remaining_minutes': hoursIncluded * 60,
            'status': 'active',
            'total_fee': totalFee,
            'amount_paid': amountPaid,
            'last_modified': nowIso,
          },
        );

        await txn.insert('sales', {
          'subscription_id': subscriptionId,
          'session_id': null,
          'final_fee': totalFee,
          'amount_paid': amountPaid,
          'tips': 0,
          'sale_time': nowIso,
          'last_modified': nowIso,
        });
      });

      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return;
    }
  }

  Future<void> makePayment({
    required Subscription sub,
    required int amount,
  }) async {
    final db = await _dbHelper.database;
    state = const AsyncValue.loading();
    try {
      await db.transaction((txn) async {
        final nowIso = DateTime.now().toUtc().toIso8601String();
        await txn.update(
          'subscriptions',
          {
            'amount_paid': sub.amountPaid + amount,
          },
          where: 'subscription_id = ?',
          whereArgs: [sub.subscriptionId],
        );

        await txn.insert('sales', {
          'subscription_id': sub.subscriptionId,
          'session_id': null,
          'final_fee': sub.totalFee,
          'amount_paid': amount,
          'tips': 0,
          'sale_time': nowIso,
          'last_modified': nowIso,
        });
      });

      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return;
    }
  }
}

final subInfoProvider =
    FutureProvider.family<List<Subscription>, String>((ref, subId) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;

  final result = await db.rawQuery('''
    SELECT s.*, p.name AS player_name
    FROM subscriptions s
    JOIN players p ON s.player_id = p.id
    WHERE s.player_id = ?
    ''', [subId]);

  if (result.isEmpty) {
    return [];
  }

  return result.map((map) => Subscription.fromMap(map)).toList();
});
