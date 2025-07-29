import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A helper function to create a testable ProviderContainer.
/// It sets up an in-memory database and overrides the databaseProvider.
Future<(ProviderContainer, Database)> createTestContainer() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.initForTest(db);

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(dbHelper),
    ],
  );

  addTearDown(() {
    db.close();
    container.dispose();
  });

  // Return both objects in a record
  return (container, db);
}
