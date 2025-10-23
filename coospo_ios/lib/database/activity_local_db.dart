import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalActivityDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    final path = join(await getDatabasesPath(), 'local_activity.db');

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

  static Future<void> insertActivity(int activityId, double calories) async {
    final db = await database;
    await db.insert(
      'activities',
      {'activity_id': activityId, 'calories': calories},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getPendingActivities() async {
    final db = await database;
    return await db.query('activities');
  }

  static Future<void> deleteActivity(int id) async {
    final db = await database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }
}
