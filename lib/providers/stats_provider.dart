// ignore: unused_import
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/utils/general.dart';

/// A provider for computing various statistics from the database.
/// Extend this notifier with methods to calculate stats as needed.
final statsProvider = Provider<StatsNotifier>((ref) {
  final dbHelper = ref.watch(databaseProvider);
  return StatsNotifier(dbHelper);
});

class StatsNotifier {
  final DatabaseHelper _dbHelper;

  StatsNotifier(this._dbHelper);
  Future<int> getProductsIncome(List<DateTime> dates,
      {bool excludeSeparatePurchases = false}) async {
    final db = await _dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();
    final String datesPlaceholders = List.filled(dates.length, '?').join(',');

    // query depending on whether to exclude separate purchases
    final String sql = '''
        SELECT quantity, price_per_item
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.sale_id
        WHERE DATE(s.sale_time) IN ($datesPlaceholders)
        ${excludeSeparatePurchases ? 'AND s.session_id IS NOT NULL' : ''}
      ''';

    final query = await db.rawQuery(sql, datesFormatted);
    if (query.isEmpty) return 0;

    // calculate income
    int totalIncome = 0;
    for (final row in query) {
      final quantity = row['quantity'] as int;
      final pricePerItem = row['price_per_item'] as int;
      totalIncome += quantity * pricePerItem;
    }
    return totalIncome;
  }

  Future<int> getPlayersIncome(List<DateTime> dates) async {
    final db = await _dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();

    // get final fee from sales where sale_time is in the provided dates
    final String placeholders = List.filled(dates.length, '?').join(',');
    final salesQuery = await db.rawQuery(
      'SELECT SUM(amount_paid) AS total FROM sales WHERE DATE(sale_time) IN ($placeholders)',
      datesFormatted,
    );
    if (salesQuery.isEmpty) return 0;

    // Substract product fees
    final productIncome =
        await getProductsIncome(dates, excludeSeparatePurchases: true);

    // and tips
    final tips = await getTips(dates);

    print(
        "salesQuery: $salesQuery, productIncome: $productIncome, tips: $tips");

    return (salesQuery.first['total'] as int? ?? 0) - productIncome - tips;
  }

  Future<int> getTips(List<DateTime> dates) async {
    final db = await _dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();

    // get tips from sales where sale_time is in the provided dates
    final String placeholders = List.filled(dates.length, '?').join(',');
    final tipsQuery = await db.rawQuery(
      'SELECT SUM(tips) AS total FROM sales WHERE DATE(sale_time) IN ($placeholders)',
      datesFormatted,
    );
    if (tipsQuery.isEmpty) return 0;

    return tipsQuery.first['total'] as int? ?? 0;
  }

  Future<int> getTotalIncome(List<DateTime> dates) async {
    final playersIncome = await getPlayersIncome(dates);
    final productsIncome = await getProductsIncome(dates);
    final tips = await getTips(dates);

    return playersIncome + productsIncome + tips;
  }
}
