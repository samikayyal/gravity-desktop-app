import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'create_test_container.dart';

void main() {
  // Initialize sqflite_ffi for testing ONCE before all tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group("checkOutPlayer", () {
    test(
        'checkOutPlayer sets all data correctly when normal player checks out (no debts or products or discount or subscription)',
        () async {
      final (container, db) = await createTestContainer();
      // Wait for the initial empty state
      await Future.microtask(() {});
      final notifier = container.read(currentPlayersProvider.notifier);

      final nowIso = DateTime.now().toUtc().toIso8601String();

      // check in a player
      await notifier.checkInPlayer(
          name: "Test Player",
          age: 10,
          timeReservedMinutes: 60,
          isOpenTime: false,
          totalFee: 95000,
          amountPaid: 95000);

      final int sessionId =
          (await db.query('player_sessions')).first['session_id'] as int;
      await notifier.checkOutPlayer(
        sessionID: sessionId,
        finalFee: 95000,
        amountPaid: 95000,
        checkoutTime: nowIso,
        debtAmount: 0,
        tips: 0,
      );

      // Verify the player's session is updated correctly
      final query = await db.query('player_sessions',
          where: 'session_id = ?', whereArgs: [sessionId]);
      expect(query.first['check_out_time'] as String, nowIso);

      // sales table
      final salesQuery = await db.query(
        'sales',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      expect(salesQuery.length, 1);
      expect(salesQuery.first['session_id'] as int, sessionId);
      expect(salesQuery.first['subscription_id'] as int?, null);
      expect(salesQuery.first['final_fee'] as int, 95000);
      expect(salesQuery.first['amount_paid'] as int, 95000);
      expect(salesQuery.first['tips'] as int, 0);
      expect(salesQuery.first['sale_time'] as String, nowIso);
      expect(salesQuery.first['discount'] as int, 0);
    });

    test(
        "checkOutPlayer sets data correctly when player with products checks out",
        () async {
      final (container, db) = await createTestContainer();
      // Wait for the initial empty state
      await Future.microtask(() {});
      final notifier = container.read(currentPlayersProvider.notifier);

      final nowIso = DateTime.now().toUtc().toIso8601String();

      // insert products first
      await db.insert('products', {
        'product_id': 3,
        'name': 'Product A',
        'price': 10000,
        'quantity_available': 100,
        'last_modified': nowIso,
      });

      await db.insert('products', {
        'product_id': 4,
        'name': 'Product B',
        'price': 25000,
        'quantity_available': 100,
        'last_modified': nowIso,
      });

      // check in a player
      final productsBought = {3: 2, 4: 3};
      await notifier.checkInPlayer(
        name: "Player with Products",
        age: 10,
        timeReservedMinutes: 60,
        isOpenTime: false,
        totalFee: 95000 + 95000,
        amountPaid: 95000 + 95000, // hour + products fee
        productsBought: productsBought,
      );

      final int sessionId =
          (await db.query('player_sessions')).first['session_id'] as int;

      // check him out
      await notifier.checkOutPlayer(
        sessionID: sessionId,
        finalFee: 95000 + 95000,
        amountPaid: 95000 + 95000,
        checkoutTime: nowIso,
        debtAmount: 0,
        tips: 0,
      );

      // Asserts db data
      // player sessions table
      final playerSession = await db.query('player_sessions',
          where: 'session_id = ?', whereArgs: [sessionId]);
      expect(playerSession.first['check_out_time'] as String, nowIso);

      // sales table
      final salesQuery = await db.query(
        'sales',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      expect(salesQuery.length, 1);
      expect(salesQuery.first['session_id'] as int, sessionId);
      expect(salesQuery.first['subscription_id'] as int?, null);
      expect(salesQuery.first['final_fee'] as int, 95000 + 95000);
      expect(salesQuery.first['amount_paid'] as int, 95000 + 95000);
      expect(salesQuery.first['tips'] as int, 0);
      expect(salesQuery.first['sale_time'] as String, nowIso);
      expect(salesQuery.first['discount'] as int, 0);

      // sale items table
      final saleId = salesQuery.first['sale_id'] as int;
      final saleItems = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );

      expect(saleItems.length, 2);
      expect(saleItems[0]['product_id'] as int, 3);
      expect(saleItems[1]['product_id'] as int, 4);

      expect(saleItems[0]['quantity'] as int, 2);
      expect(saleItems[1]['quantity'] as int, 3);

      expect(saleItems[0]['price_per_item'] as int, 10000);
      expect(saleItems[1]['price_per_item'] as int, 25000);

      // Assert: session_products is empty
      final sessionProducts = await db.query(
        'session_products',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      expect(sessionProducts.isEmpty, true);
    });

    test("checkOutPlayer sets data correctly when tips are received", () async {
      final (container, db) = await createTestContainer();
      // Wait for the initial empty state
      await Future.microtask(() {});
      final notifier = container.read(currentPlayersProvider.notifier);

      final nowIso = DateTime.now().toUtc().toIso8601String();

      await notifier.checkInPlayer(
        name: "Player with Tip",
        age: 10,
        timeReservedMinutes: 60,
        isOpenTime: false,
        totalFee: 95000,
        amountPaid: 95000,
      );

      final int sessionId =
          (await db.query('player_sessions')).first['session_id'] as int;

      // check him out
      await notifier.checkOutPlayer(
        sessionID: sessionId,
        finalFee: 95000,
        amountPaid: 95000 + 15000, // 15k tip
        checkoutTime: nowIso,
        debtAmount: 0,
        tips: 15000,
      );

      // Asserts db data
      // player sessions table
      final playerSession = await db.query('player_sessions',
          where: 'session_id = ?', whereArgs: [sessionId]);
      expect(playerSession.first['check_out_time'] as String, nowIso);

      // sales table
      final salesQuery = await db.query(
        'sales',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      expect(salesQuery.length, 1);
      expect(salesQuery.first['session_id'] as int, sessionId);
      expect(salesQuery.first['subscription_id'] as int?, null);
      expect(salesQuery.first['final_fee'] as int, 95000);
      expect(salesQuery.first['amount_paid'] as int, 95000 + 15000);
      expect(salesQuery.first['tips'] as int, 15000);
      expect(salesQuery.first['sale_time'] as String, nowIso);
      expect(salesQuery.first['discount'] as int, 0);
    });

    test("checkOutPlayer sets data correctly when discount is applied",
        () async {
      final (container, db) = await createTestContainer();
      await Future.microtask(() {});
      final notifier = container.read(currentPlayersProvider.notifier);

      final nowIso = DateTime.now().toUtc().toIso8601String();

      await notifier.checkInPlayer(
        name: "Player with Discount",
        age: 15,
        timeReservedMinutes: 60,
        isOpenTime: false,
        totalFee: 95000,
        amountPaid: 0,
      );

      final int sessionId =
          (await db.query('player_sessions')).first['session_id'] as int;

      // Check out with 20% discount (19000)
      await notifier.checkOutPlayer(
        sessionID: sessionId,
        finalFee: 76000, // 95000 - 19000 discount
        amountPaid: 76000,
        checkoutTime: nowIso,
        debtAmount: 0,
        tips: 0,
        discount: 19000,
        discountReason: "Student discount",
      );

      // Verify sales table
      final salesQuery = await db.query(
        'sales',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      expect(salesQuery.length, 1);
      expect(salesQuery.first['session_id'] as int, sessionId);
      expect(salesQuery.first['subscription_id'] as int?, null);
      expect(salesQuery.first['final_fee'] as int, 76000);
      expect(salesQuery.first['amount_paid'] as int, 76000);
      expect(salesQuery.first['discount'] as int, 19000);
      expect(salesQuery.first['discount_reason'] as String, "Student discount");
      expect(salesQuery.first['tips'] as int, 0);
    });

    test("checkOutPlayer behaves correctly when debt is present", () async {
      final (container, db) = await createTestContainer();
      await Future.microtask(() {});
      final notifier = container.read(currentPlayersProvider.notifier);

      final nowIso = DateTime.now().toUtc().toIso8601String();

      await notifier.checkInPlayer(
        name: "Player with Debt",
        age: 12,
        timeReservedMinutes: 60,
        isOpenTime: false,
        totalFee: 95000,
        amountPaid: 50000, // Partial payment
      );

      final int sessionId =
          (await db.query('player_sessions')).first['session_id'] as int;

      final String playerId = (await db.query('player_sessions',
              where: 'session_id = ?', whereArgs: [sessionId]))
          .first['player_id'] as String;

      // Check out with remaining debt
      await notifier.checkOutPlayer(
        sessionID: sessionId,
        finalFee: 95000,
        amountPaid: 70000, // Still 25000 short
        checkoutTime: nowIso,
        debtAmount: 25000,
        tips: 0,
      );

      // Verify sales table shows correct amounts
      final salesQuery = await db.query(
        'sales',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      expect(salesQuery.length, 1);
      expect(salesQuery.first['final_fee'] as int, 95000);
      expect(salesQuery.first['amount_paid'] as int, 70000);

      // debts table
      final debts = await db.query('debts');

      expect(debts.length, 1);
      expect(debts.first['player_id'], playerId);
      expect(debts.first['amount'] as int, 25000);
      expect(debts.first['session_id'] as int, sessionId);
      expect(debts.first['created_at'] as String, nowIso);
    });

    test(
        "checkOutPlayer handles complex scenario with products, tips, and discount",
        () async {
      final (container, db) = await createTestContainer();
      await Future.microtask(() {});
      final notifier = container.read(currentPlayersProvider.notifier);

      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Add test products
      await db.insert('products', {
        'product_id': 5,
        'name': 'Energy Drink',
        'price': 15000,
        'quantity_available': 50,
        'last_modified': nowIso,
      });

      await db.insert('products', {
        'product_id': 6,
        'name': 'Protein Bar',
        'price': 12000,
        'quantity_available': 30,
        'last_modified': nowIso,
      });

      final productsBought = {5: 1, 6: 2}; // 1 energy drink + 2 protein bars
      final productsCost = 15000 + (12000 * 2); // 39000

      await notifier.checkInPlayer(
        name: "Complex Checkout Player",
        age: 18,
        timeReservedMinutes: 90, // 1.5 hours
        isOpenTime: false,
        totalFee: 95000 +
            45000 +
            productsCost, // hour + additional half hour + products
        amountPaid: 50000,
        productsBought: productsBought,
      );

      final int sessionId =
          (await db.query('player_sessions')).first['session_id'] as int;

      await notifier.checkOutPlayer(
        sessionID: sessionId,
        finalFee: 95000 + 45000 + productsCost,
        amountPaid: 95000 +
            45000 +
            productsCost +
            16000 -
            20000, // total fee + tips - discount
        checkoutTime: nowIso,
        debtAmount: 0,
        tips: 16000,
        discount: 20000,
        discountReason: "VIP customer",
      );

      // Verify sales table
      final salesQuery = await db.query(
        'sales',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      expect(salesQuery.length, 1);
      expect(
          salesQuery.first['final_fee'] as int, 95000 + 45000 + productsCost);
      expect(salesQuery.first['amount_paid'] as int,
          95000 + 45000 + productsCost + 16000 - 20000);
      expect(salesQuery.first['tips'] as int, 16000);
      expect(salesQuery.first['discount'] as int, 20000);
      expect(salesQuery.first['discount_reason'] as String, "VIP customer");

      // Verify sale items
      final saleId = salesQuery.first['sale_id'] as int;
      final saleItems = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
        orderBy: 'product_id ASC',
      );

      expect(saleItems.length, 2);
      expect(saleItems[0]['product_id'] as int, 5);
      expect(saleItems[0]['quantity'] as int, 1);
      expect(saleItems[0]['price_per_item'] as int, 15000);

      expect(saleItems[1]['product_id'] as int, 6);
      expect(saleItems[1]['quantity'] as int, 2);
      expect(saleItems[1]['price_per_item'] as int, 12000);

      // Verify session products are cleared
      final sessionProducts = await db.query(
        'session_products',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      expect(sessionProducts.isEmpty, true);
    });
  });
}
