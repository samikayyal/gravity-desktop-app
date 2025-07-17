import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gravity_desktop_app/database/database.dart';
import 'package:gravity_desktop_app/models/note.dart';
import 'package:gravity_desktop_app/providers/current_players_provider.dart';

final notesProvider =
    StateNotifierProvider<NotesProvider, AsyncValue<List<Note>>>((ref) {
  final db = ref.watch(databaseProvider);
  return NotesProvider(db);
});

class NotesProvider extends StateNotifier<AsyncValue<List<Note>>> {
  final DatabaseHelper _dbHelper;

  NotesProvider(this._dbHelper) : super(const AsyncValue.loading()) {
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    state = const AsyncValue.loading();
    try {
      final db = await _dbHelper.database;
      final notesQuery = await db.rawQuery(
        'SELECT * FROM notes WHERE deleted = 0 ORDER BY created_at DESC',
      );

      final List<Note> notes = notesQuery
          .map(
            (e) => Note.fromMap(e as Map<String, dynamic>),
          )
          .toList();
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _fetchNotes();
  }

  Future<void> addNote(String note) async {
    state = const AsyncValue.loading();
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        'notes',
        {'note': note, 'created_at': now, 'last_modified': now},
      );
      await _fetchNotes();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteNote(String noteId) async {
    state = const AsyncValue.loading();
    try {
      final db = await _dbHelper.database;
      await db.update(
        'notes',
        {'deleted': 1},
        where: 'note_id = ?',
        whereArgs: [noteId],
      );
      await _fetchNotes();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
