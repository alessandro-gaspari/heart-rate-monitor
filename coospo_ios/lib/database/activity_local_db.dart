import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalActivityDatabase {
  static Database? _database;

  // Ottiene o crea il database locale
  static Future<Database> get database async {
    if (_database != null) return _database!;

    // Percorso del file del database
    final path = join(await getDatabasesPath(), 'local_activity.db');

    // Crea il database con una tabella "activities"
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activities(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity_id INTEGER,
            calories REAL
          )
        ''');
      },
    );
    return _database!;
  }

  // Inserisce una nuova attività nel database
  static Future<void> insertActivity(int activityId, double calories) async {
    final db = await database;
    await db.insert(
      'activities',
      {'activity_id': activityId, 'calories': calories},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Restituisce tutte le attività salvate
  static Future<List<Map<String, dynamic>>> getPendingActivities() async {
    final db = await database;
    return await db.query('activities');
  }

  // Elimina un’attività tramite il suo id
  static Future<void> deleteActivity(int id) async {
    final db = await database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }
}