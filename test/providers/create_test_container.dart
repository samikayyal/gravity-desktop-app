import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A helper function to create a testable ProviderContainer.
/// It sets up an in-memory database and overrides the databaseProvider.
Future<(ProviderContainer, Database)> createTestContainer(
    {List<Override> overrides = const []}) async {
  print("A");
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  print("B");
  final dbHelper = DatabaseHelper.instance;
  print("C");
  await dbHelper.initForTest(db);
  print("D");

  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(dbHelper), ...overrides],
  );
  print("E");

  // await Future.value();
  print("F");

  addTearDown(() {
    db.close();
    container.dispose();
  });

  // Return both objects in a record
  return (container, db);
}
