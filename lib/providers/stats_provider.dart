// ignore: unused_import
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/utils/constants.dart';
import 'package:gravity_desktop_app/utils/general.dart';

// ---------------- Product Income Provider ----------------
class ProductIncomeParams {
  final List<DateTime> dates;
  final bool excludeSeparatePurchases;

  ProductIncomeParams(this.dates, {this.excludeSeparatePurchases = false});
}

final productsIncomeProvider = FutureProvider.autoDispose
    .family<int, ProductIncomeParams>((ref, params) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
  final List<String> datesFormatted =
      params.dates.map((date) => date.toYYYYMMDD()).toList();
  final String datesPlaceholders =
      List.filled(params.dates.length, '?').join(',');

  // query depending on whether to exclude separate purchases
  final String sql = '''
        SELECT quantity, price_per_item
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.sale_id
        WHERE DATE(s.sale_time) IN ($datesPlaceholders)
        ${params.excludeSeparatePurchases ? 'AND s.session_id IS NOT NULL' : ''}
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
});

// ---------------- Players Income provider ----------------
final playersIncomeProvider =
    FutureProvider.autoDispose.family<int, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();

  // get final fee from sales where sale_time is in the provided dates
  final String placeholders = List.filled(dates.length, '?').join(',');
  final salesQuery = await db.rawQuery(
    '''
      SELECT SUM(amount_paid) AS total
      FROM sales 
      WHERE DATE(sale_time) IN ($placeholders)
      AND session_id IS NOT NULL
      AND subscription_id IS NULL
      ''',
    datesFormatted,
  );
  if (salesQuery.isEmpty) return 0;

  // Substract product fees
  final productIncome = await ref.watch(
    productsIncomeProvider(ProductIncomeParams(dates)).future,
  );

  // and tips
  final tips = await ref.watch(tipsProvider(dates).future);

  // log("salesQuery: $salesQuery, productIncome: $productIncome, tips: $tips");

  return (salesQuery.first['total'] as int? ?? 0) - productIncome - tips;
});

// ---------------- Tips provider ----------------
final tipsProvider =
    FutureProvider.autoDispose.family<int, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
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
});

// ---------------- total income provider ----------------
final totalIncomeProvider =
    FutureProvider.autoDispose.family<int, List<DateTime>>((ref, dates) async {
  final playersIncome = await ref.watch(playersIncomeProvider(dates).future);
  final productsIncome = await ref
      .watch(productsIncomeProvider(ProductIncomeParams(dates)).future);
  final tips = await ref.watch(tipsProvider(dates).future);

  return playersIncome + productsIncome + tips;
});

// ---------------- Subscription Revenue ----------------
final subscriptionRevenueProvider =
    FutureProvider.autoDispose.family<int, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();
  final String placeholders = List.filled(dates.length, '?').join(',');

  final query = await db.rawQuery(
    '''
      SELECT SUM(amount_paid) AS total
      FROM sales 
      WHERE DATE(sale_time) IN ($placeholders)
      AND subscription_id IS NOT NULL
      ''',
    datesFormatted,
  );

  return query.first['total'] as int? ?? 0;
});

// ---------------- Age Groups Provider ----------------
class AgeGroupData {
  final String ageGroup;
  final int count;
  final Color color;

  AgeGroupData(this.ageGroup, this.count, this.color);
}

final ageGroupsProvider = FutureProvider.autoDispose
    .family<List<AgeGroupData>, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();
  final String placeholders = List.filled(dates.length, '?').join(',');

  final query = await db.rawQuery(
    '''
    SELECT 
      CASE 
        WHEN age BETWEEN 1 AND 2 THEN '1-2'
        WHEN age BETWEEN 3 AND 5 THEN '3-5'
        WHEN age BETWEEN 6 AND 8 THEN '6-8'
        WHEN age BETWEEN 9 AND 11 THEN '9-11'
        WHEN age BETWEEN 12 AND 14 THEN '12-14'
        WHEN age BETWEEN 15 AND 17 THEN '15-17'
        WHEN age BETWEEN 18 AND 20 THEN '18-20'
        WHEN age BETWEEN 21 AND 26 THEN '21-26'
        ELSE 'Over 26'
      END AS age_group,
      COUNT(*) AS count
    FROM player_sessions ps
    LEFT JOIN players p ON p.id = ps.player_id
    WHERE DATE(check_in_time) IN ($placeholders)
    GROUP BY age_group
    ''',
    datesFormatted,
  );

  Map<String, int> ageGroups = {};
  for (final row in query) {
    ageGroups[row['age_group'] as String] = row['count'] as int;
  }

  final ageGroupsList = ageGroups.entries.map((entry) {
    final ageGroup = entry.key;
    final count = entry.value;

    // Assign colors based on age group
    Color color;
    switch (ageGroup) {
      case '1-2':
        color = Colors.red[700]!;
        break;
      case '3-5':
        color = Colors.orange[700]!;
        break;
      case '6-8':
        color = Colors.amber[800]!;
        break;
      case '9-11':
        color = Colors.green[700]!;
        break;
      case '12-14':
        color = Colors.blue[700]!;
        break;
      case '15-17':
        color = Colors.indigo[700]!;
        break;
      case '18-20':
        color = Colors.purple[700]!;
        break;
      case '21-26':
        color = Colors.pink[700]!;
        break;
      default: // over 26
        color = Colors.teal[700]!;
    }

    return AgeGroupData(ageGroup, count, color);
  }).toList();
  ageGroupsList.sort((a, b) {
    const order = [
      '1-2',
      '3-5',
      '6-8',
      '9-11',
      '12-14',
      '15-17',
      '18-20',
      '21-26',
      'Over 26'
    ];
    return order.indexOf(a.ageGroup).compareTo(order.indexOf(b.ageGroup));
  });
  return ageGroupsList;
});

// ---------------- Busiest Hours Provider ----------------
class BusiestHoursData {
  final String hours;
  final int playerCount;

  const BusiestHoursData({required this.hours, required this.playerCount});
}

final busiestHoursProvider = FutureProvider.autoDispose
    .family<List<BusiestHoursData>, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;

  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();
  final String placeholders = List.filled(dates.length, '?').join(',');

  final query = await db.rawQuery(
    '''
      SELECT
        CAST(strftime('%H', check_in_time) AS INTEGER) AS hour,
        COUNT(*) AS count
      FROM player_sessions
      WHERE DATE(check_in_time) IN ($placeholders)
      GROUP BY hour
      ORDER BY count DESC
      ''',
    datesFormatted,
  );

  List<BusiestHoursData> hourlyCheckIns = [];
  for (final row in query) {
    final int hourInt = row['hour'] as int;
    final int displayHour = hourInt % 12 == 0 ? 12 : hourInt % 12;
    final String period = hourInt < 12 ? 'AM' : 'PM';
    final String hours = '$displayHour $period';
    hourlyCheckIns
        .add(BusiestHoursData(hours: hours, playerCount: row['count'] as int));
  }
  // sort based on hour
  hourlyCheckIns.sort((a, b) => b.playerCount.compareTo(a.playerCount));

  return hourlyCheckIns;
});

// ---------------- Peak capacity provider ----------------
final peakCapacityProvider =
    FutureProvider.autoDispose.family<int, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();
  final String placeholders = List.filled(dates.length, '?').join(',');

  // Get all sessions within the date range
  final sessionsQuery = await db.rawQuery(
    '''
      SELECT check_in_time, check_out_time
      FROM player_sessions
      WHERE DATE(check_in_time) IN ($placeholders)
      OR (check_out_time IS NOT NULL AND DATE(check_out_time) IN ($placeholders))
      ''',
    [...datesFormatted, ...datesFormatted],
  );

  if (sessionsQuery.isEmpty) return 0;

  int max = 0;

  for (var session in sessionsQuery) {
    final DateTime checkInTime =
        DateTime.parse(session['check_in_time'] as String);
    final DateTime? checkOutTime = session['check_out_time'] != null
        ? DateTime.parse(session['check_out_time'] as String)
        : null;
    if (checkOutTime == null) continue;

    // Check how many sessions overlap with this one
    int count = 0;
    for (var otherSession in sessionsQuery) {
      final DateTime otherCheckInTime =
          DateTime.parse(otherSession['check_in_time'] as String);
      final DateTime? otherCheckOutTime = otherSession['check_out_time'] != null
          ? DateTime.parse(otherSession['check_out_time'] as String)
          : null;

      if (otherCheckOutTime == null) continue;

      if (checkInTime.isBefore(otherCheckOutTime) &&
          otherCheckInTime.isBefore(checkOutTime)) {
        count++;
      }
    }
    max = count > max ? count : max;
  }
  return max;
});

// ---------------- Discount data provider ----------------
class DiscountData {
  final int totalNumberofDiscounts;
  final int totalDiscountAmount;

  const DiscountData({
    required this.totalNumberofDiscounts,
    required this.totalDiscountAmount,
  });
}

final discountDataProvider = FutureProvider.autoDispose
    .family<DiscountData, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;

  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();
  final String placeholders = List.filled(dates.length, '?').join(',');

  final query = await db.rawQuery(
    '''
      SELECT 
        COUNT(*) AS total_discounts,
        SUM(discount) AS total_discount_amount
      FROM sales
      WHERE DATE(sale_time) IN ($placeholders)
      AND discount > 0
    ''',
    datesFormatted,
  );
  if (query.isEmpty) {
    return DiscountData(
      totalNumberofDiscounts: 0,
      totalDiscountAmount: 0,
    );
  }

  return DiscountData(
      totalDiscountAmount: (query.first['total_discount_amount'] as int?) ?? 0,
      totalNumberofDiscounts: (query.first['total_discounts'] as int?) ?? 0);
});

// ---------------- Top Players Provider ----------------
class TopPlayer {
  final String playerId;
  final String name;
  final Duration timeSpent;
  final int sessionCount;

  const TopPlayer({
    required this.playerId,
    required this.name,
    required this.timeSpent,
    required this.sessionCount,
  });
}

final topPlayersProvider = FutureProvider.autoDispose
    .family<List<TopPlayer>, List<DateTime>>((ref, dates) async {
  final dbHelper = ref.watch(databaseProvider);
  final db = await dbHelper.database;
  final List<String> datesFormatted =
      dates.map((date) => date.toYYYYMMDD()).toList();
  final String placeholders = List.filled(dates.length, '?').join(',');

  final query = await db.rawQuery(
    '''
      SELECT 
        p.id,
        p.name,
        p.age,
        COUNT(ps.session_id) AS visit_count,
        SUM(CASE WHEN ps.check_out_time IS NOT NULL 
            THEN (julianday(ps.check_out_time) - julianday(ps.check_in_time)) * 24 * 60
            ELSE 0 END) AS total_minutes
      FROM player_sessions ps
      JOIN players p ON ps.player_id = p.id
      WHERE DATE(ps.check_in_time) IN ($placeholders)
      GROUP BY p.id, p.name, p.age
      ORDER BY visit_count DESC, total_minutes DESC
      LIMIT 10
      ''',
    datesFormatted,
  );

  return query
      .map((row) => TopPlayer(
          playerId: row['id'] as String,
          name: row['name'] as String,
          timeSpent: Duration(
              minutes: (row['total_minutes'] as double? ?? 0.0).round()),
          sessionCount: row['visit_count'] as int))
      .toList();
});

// ---------------- Product Sales Provider ----------------
class ProductSale {
  final String name;
  final int productId;
  final int quantitySold;
  final int totalRevenue;

  const ProductSale({
    required this.name,
    required this.productId,
    required this.quantitySold,
    required this.totalRevenue,
  });
}

final productSalesProvider =
    FutureProvider.autoDispose.family<List<ProductSale>, List<DateTime>>(
  (ref, dates) async {
    final dbHelper = ref.watch(databaseProvider);
    final db = await dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();
    final String placeholders = List.filled(dates.length, '?').join(',');

    // Total sales per product
    final salesQuery = await db.rawQuery(
      '''
      SELECT 
        p.product_id,
        p.name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.quantity * si.price_per_item) AS total_revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.sale_id
      JOIN products p ON si.product_id = p.product_id
      WHERE DATE(s.sale_time) IN ($placeholders)
      GROUP BY p.product_id, p.name
      ORDER BY total_revenue DESC
      ''',
      datesFormatted,
    );

    List<ProductSale> productSales = [];
    for (var sale in salesQuery) {
      productSales.add(ProductSale(
          name: sale['name'] as String,
          productId: sale['product_id'] as int,
          quantitySold: sale['total_quantity'] as int,
          totalRevenue: sale['total_revenue'] as int));
    }
    return productSales;
  },
);

// ---------------- Player Chart Data Provider ----------------
class GravityLineChartData {
  final DateTime time;
  final int playerCount;
  final int productSaleCount;

  const GravityLineChartData(
      {required this.time,
      required this.playerCount,
      required this.productSaleCount});
}

enum LineChartBucketSize { hourly, daily, weekly, monthly }

final lineChartDataProvider = FutureProvider.autoDispose
    .family<List<GravityLineChartData>, List<DateTime>>(
  (ref, dates) async {
    final dbHelper = ref.watch(databaseProvider);
    final db = await dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();
    final String placeholders = List.filled(dates.length, '?').join(',');

    // Determine granularity based on date range length
    final LineChartBucketSize bucketSize;
    if (dates.length < minDatesForDailyBuckets) {
      bucketSize = LineChartBucketSize.hourly;
    } else if (dates.length < minDatesForWeeklyBuckets) {
      bucketSize = LineChartBucketSize.daily;
    } else if (dates.length < minDatesForMonthlyBuckets) {
      bucketSize = LineChartBucketSize.weekly;
    } else {
      // monthly
      bucketSize = LineChartBucketSize.monthly;
    }

    String groupBy;
    String productGroupBy;
    if (bucketSize == LineChartBucketSize.hourly) {
      groupBy = "strftime('%Y-%m-%d %H', check_in_time)";
      productGroupBy = "strftime('%Y-%m-%d %H', s.sale_time)";
    } else if (bucketSize == LineChartBucketSize.daily) {
      groupBy = "DATE(check_in_time)";
      productGroupBy = "DATE(s.sale_time)";
    } else if (bucketSize == LineChartBucketSize.weekly) {
      // Weekly: Group by year-week (e.g., "2025-30" for week 30 of 2025)
      groupBy = "strftime('%Y-%W', check_in_time)";
      productGroupBy = "strftime('%Y-%W', s.sale_time)";
    } else {
      // Monthly: Group by year-month (e.g., "2025-07" for July 2025)
      groupBy = "strftime('%Y-%m', check_in_time)";
      productGroupBy = "strftime('%Y-%m', s.sale_time)";
    }

    // Get player check-in data
    final playerQuery = await db.rawQuery(
      '''
      SELECT 
        $groupBy AS time_bucket,
        COUNT(*) AS player_count
      FROM player_sessions
      WHERE DATE(check_in_time) IN ($placeholders)
      GROUP BY time_bucket
      ORDER BY time_bucket
      ''',
      datesFormatted,
    );
    log(playerQuery.toString());

    // Get product sales data
    final productQuery = await db.rawQuery(
      '''
      SELECT 
        $productGroupBy AS time_bucket,
        SUM(si.quantity) AS product_sale_count
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.sale_id
      WHERE DATE(s.sale_time) IN ($placeholders)
      GROUP BY time_bucket
      ORDER BY time_bucket
      ''',
      datesFormatted,
    );

    // Create maps for easy lookup
    Map<String, int> playerData = {};
    for (final row in playerQuery) {
      playerData[row['time_bucket'] as String] = row['player_count'] as int;
    }

    Map<String, int> productData = {};
    for (final row in productQuery) {
      productData[row['time_bucket'] as String] =
          row['product_sale_count'] as int;
    }

    // Combine data for all time buckets
    Set<String> allTimeBuckets = {...playerData.keys, ...productData.keys};

    List<GravityLineChartData> chartData = [];
    for (final timeBucket in allTimeBuckets) {
      final playerCount = playerData[timeBucket] ?? 0;
      final productSaleCount = productData[timeBucket] ?? 0;

      DateTime timePoint;
      if (bucketSize == LineChartBucketSize.hourly) {
        timePoint = DateTime.parse('$timeBucket:00:00');
      } else if (bucketSize == LineChartBucketSize.daily) {
        timePoint = DateTime.parse(timeBucket);
      } else if (bucketSize == LineChartBucketSize.weekly) {
        // Weekly format is "YYYY-WW", convert to first day of that week
        final parts = timeBucket.split('-');
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        // Calculate the first day of the week (Monday)
        final firstDayOfYear = DateTime(year, 1, 1);
        final daysToAdd = (week - 1) * 7 - firstDayOfYear.weekday + 1;
        timePoint = firstDayOfYear.add(Duration(days: daysToAdd));
      } else {
        // Monthly format is "YYYY-MM", convert to first day of that month
        final parts = timeBucket.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        timePoint = DateTime(year, month, 1);
      }

      chartData.add(GravityLineChartData(
        time: timePoint,
        playerCount: playerCount,
        productSaleCount: productSaleCount,
      ));
    }

    // Sort by time
    chartData.sort((a, b) => a.time.compareTo(b.time));

    return chartData;
  },
);
// ---------------- ----------------
// ---------------- ----------------
// ---------------- ----------------
// ---------------- ----------------

class StatsNotifier {
  final DatabaseHelper _dbHelper;

  StatsNotifier(this._dbHelper);

  /// Get subscription statistics
  Future<Map<String, dynamic>> getSubscriptionStats(
      List<DateTime> dates) async {
    final db = await _dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();
    final String placeholders = List.filled(dates.length, '?').join(',');

    // Active subscriptions count
    final activeQuery = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM subscriptions
      WHERE status = 'active'
      AND DATE(start_date) <= ?
      AND DATE(expiry_date) >= ?
      ''',
      [dates.last.toYYYYMMDD(), dates.first.toYYYYMMDD()],
    );

    // Expired subscriptions in date range
    final expiredQuery = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM subscriptions
      WHERE status = 'expired'
      AND DATE(expiry_date) IN ($placeholders)
      ''',
      datesFormatted,
    );

    // New subscriptions in date range
    final newSubsQuery = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM subscriptions
      WHERE DATE(start_date) IN ($placeholders)
      ''',
      datesFormatted,
    );

    // Average utilization rate
    final utilizationQuery = await db.rawQuery(
      '''
      SELECT 
        AVG(CAST(total_minutes - remaining_minutes AS REAL) / total_minutes * 100) AS avg_utilization
      FROM subscriptions
      WHERE status IN ('active', 'expired', 'finished')
      AND DATE(start_date) <= ?
      ''',
      [dates.last.toYYYYMMDD()],
    );

    return {
      'activeCount': activeQuery.first['count'] as int,
      'expiredCount': expiredQuery.first['count'] as int,
      'newSubscriptionsCount': newSubsQuery.first['count'] as int,
      'averageUtilization':
          utilizationQuery.first['avg_utilization'] as double? ?? 0.0,
    };
  }

  /// Get product sales details
  Future<Map<String, dynamic>> getProductSalesDetails(
      List<DateTime> dates) async {
    final db = await _dbHelper.database;
    final List<String> datesFormatted =
        dates.map((date) => date.toYYYYMMDD()).toList();
    final String placeholders = List.filled(dates.length, '?').join(',');

    // Total sales per product
    final salesQuery = await db.rawQuery(
      '''
      SELECT 
        p.name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.quantity * si.price_per_item) AS total_revenue,
        AVG(si.price_per_item) AS avg_price
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.sale_id
      JOIN products p ON si.product_id = p.product_id
      WHERE DATE(s.sale_time) IN ($placeholders)
      GROUP BY p.product_id, p.name
      ORDER BY total_revenue DESC
      ''',
      datesFormatted,
    );

    List<Map<String, dynamic>> productSales = [];
    int totalRevenue = 0;
    int totalQuantity = 0;

    for (final row in salesQuery) {
      final revenue = row['total_revenue'] as int;
      final quantity = row['total_quantity'] as int;
      totalRevenue += revenue;
      totalQuantity += quantity;

      productSales.add({
        'name': row['name'] as String,
        'quantity': quantity,
        'revenue': revenue,
        'averagePrice': row['avg_price'] as double,
      });
    }

    return {
      'products': productSales,
      'totalRevenue': totalRevenue,
      'totalQuantity': totalQuantity,
    };
  }
}
