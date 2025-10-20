import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _database;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'coospo_local.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabella attività locali
        await db.execute('''
          CREATE TABLE activities (
            id INTEGER PRIMARY KEY,
            device_id TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            distance_km REAL DEFAULT 0,
            avg_speed REAL DEFAULT 0,
            avg_heart_rate INTEGER DEFAULT 0,
            calories REAL DEFAULT 0,
            status TEXT DEFAULT 'completed',
            synced INTEGER DEFAULT 0
          )
        ''');
        
        // Tabella waypoints locali
        await db.execute('''
          CREATE TABLE waypoints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity_id INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            heart_rate INTEGER,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (activity_id) REFERENCES activities (id)
          )
        ''');
        
        print('✅ Database locale creato');
      },
    );
  }
  
  // Salva attività in locale
  static Future<void> saveActivity(Map<String, dynamic> activity) async {
    final db = await database;
    
    await db.insert(
      'activities',
      activity,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('✅ Attività salvata in locale: ${activity['id']}');
  }
  
  // Salva waypoints in locale
  static Future<void> saveWaypoints(int activityId, List<Map<String, dynamic>> waypoints) async {
    final db = await database;
    
    for (var waypoint in waypoints) {
      await db.insert(
        'waypoints',
        {
          'activity_id': activityId,
          'latitude': waypoint['latitude'],
          'longitude': waypoint['longitude'],
          'heart_rate': waypoint['heart_rate'],
          'timestamp': waypoint['timestamp'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    print('✅ ${waypoints.length} waypoints salvati in locale');
  }
  
  // Ottieni attività dal locale per device_id
  static Future<List<Map<String, dynamic>>> getActivitiesByDevice(String deviceId) async {
    final db = await database;
    
    final activities = await db.query(
      'activities',
      where: 'device_id = ? AND status = ?',
      whereArgs: [deviceId, 'completed'],
      orderBy: 'start_time DESC',
    );
    
    return activities;
  }
  
  // Ottieni waypoints per attività
  static Future<List<Map<String, dynamic>>> getWaypoints(int activityId) async {
    final db = await database;
    
    final waypoints = await db.query(
      'waypoints',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp ASC',
    );
    
    return waypoints;
  }
  
  // Ottieni singola attività con waypoints
  static Future<Map<String, dynamic>?> getActivityWithWaypoints(int activityId) async {
    final db = await database;
    
    final activities = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [activityId],
    );
    
    if (activities.isEmpty) return null;
    
    final activity = Map<String, dynamic>.from(activities.first);
    final waypoints = await getWaypoints(activityId);
    
    activity['waypoints'] = waypoints;
    
    return activity;
  }
  
  // Segna attività come sincronizzata
  static Future<void> markAsSynced(int activityId) async {
    final db = await database;
    
    await db.update(
      'activities',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }
}
