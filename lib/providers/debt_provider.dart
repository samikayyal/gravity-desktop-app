import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/debt.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';

final debtProvider =
    StateNotifierProvider<DebtNotifier, AsyncValue<List<Debt>>>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return DebtNotifier(dbHelper);
});

class DebtNotifier extends StateNotifier<AsyncValue<List<Debt>>> {
  final DatabaseHelper dbHelper;

  DebtNotifier(this.dbHelper) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final db = await dbHelper.database;
      final query = await db.rawQuery('''
        SELECT d.debt_id, d.player_id, p.name AS player_name,
               d.session_id, d.amount, d.reason, d.created_at
        FROM debts d
        JOIN players p ON d.player_id = p.id
        WHERE d.amount > 0
        ORDER BY d.created_at DESC
        ''');
      final debts = query.map((e) => Debt.fromMap(e)).toList();
      state = AsyncValue.data(debts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addDebt(Debt debt) async {
    state = const AsyncValue.loading();
    try {
      final db = await dbHelper.database;
      await db.insert('debts', debt.toMap());
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDebt(Debt debt) async {
    state = const AsyncValue.loading();
    try {
      final db = await dbHelper.database;
      await db.update(
        'debts',
        debt.toMap(),
        where: 'debt_id = ?',
        whereArgs: [debt.debtId],
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteDebt(int id) async {
    state = const AsyncValue.loading();
    try {
      final db = await dbHelper.database;
      await db.delete(
        'debts',
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> payDebt(int id, int amount) async {
    state = const AsyncValue.loading();
    try {
      final db = await dbHelper.database;
      final debt = state.value?.firstWhere((d) => d.debtId == id);
      if (debt == null) {
        throw Exception('Debt not found');
      }
      if (amount > debt.amount) {
        throw Exception('Payment exceeds debt amount');
      }
      await db.rawUpdate(
        '''
        UPDATE debts
        SET amount = amount - ?
        WHERE debt_id = ?
        ''',
        [amount, id],
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
