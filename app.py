from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import sqlite3
import base64
import os
from datetime import datetime
from math import radians, sin, cos, sqrt, atan2

app = Flask(__name__)
app.config['SECRET_KEY'] = 'coospo_heart_rate_monitor_secret_2024'
CORS(app)

socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Connessione al database SQLite
def get_db_connection():
    conn = sqlite3.connect('heart_rate.db')
    conn.row_factory = sqlite3.Row
    return conn

# Migrazione database per aggiungere colonne GPS
def migrate_db():
    """Aggiunge colonne GPS se non esistono"""
    try:
        conn = sqlite3.connect('heart_rate.db')
        cursor = conn.cursor()
        
        cursor.execute("PRAGMA table_info(heart_rate_data)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'latitude' not in columns:
            cursor.execute('ALTER TABLE heart_rate_data ADD COLUMN latitude REAL')
            print('✅ Colonna latitude aggiunta')
        
        if 'longitude' not in columns:
            cursor.execute('ALTER TABLE heart_rate_data ADD COLUMN longitude REAL')
            print('✅ Colonna longitude aggiunta')
        
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"⚠️ Errore migrazione: {e}")

# Inizializza database heart rate
def init_db():
    conn = sqlite3.connect('heart_rate.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS heart_rate_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            heart_rate INTEGER NOT NULL,
            latitude REAL,
            longitude REAL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()
    print('✅ Database inizializzato')

# Inizializza database activities
def init_activities_db():
    """Crea tabelle per attività e waypoints"""
    conn = sqlite3.connect('heart_rate.db')
    cursor = conn.cursor()
    
    # Tabella attività
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS activities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            start_time DATETIME NOT NULL,
            end_time DATETIME,
            distance_km REAL DEFAULT 0,
            avg_speed REAL DEFAULT 0,
            avg_heart_rate INTEGER DEFAULT 0,
            calories REAL DEFAULT 0,
            status TEXT DEFAULT 'active',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Tabella waypoints
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS waypoints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activity_id INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            heart_rate INTEGER,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (activity_id) REFERENCES activities (id)
        )
    ''')
    
    conn.commit()
    conn.close()
    print('✅ Database attività inizializzato')

# Funzione helper: calcola distanza tra waypoints
def calculate_distance(waypoints):
    """Calcola distanza totale in km tra waypoints usando formula Haversine"""
    if len(waypoints) < 2:
        return 0.0
    
    total_distance = 0.0
    
    for i in range(len(waypoints) - 1):
        lat1, lon1 = waypoints[i]
        lat2, lon2 = waypoints[i + 1]
        
        R = 6371  # Raggio Terra in km
        
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        
        a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        distance = R * c
        total_distance += distance
    
    return total_distance

import base64

def decode_heart_rate(data):
    try:
        encoded_data = data.get('data', '')
        
        if not encoded_data:
            print("❌ Nessun dato 'data' nel messaggio")
            return 0
        
        raw_data = base64.b64decode(encoded_data)
        
        if len(raw_data) == 0:
            print("❌ Dati vuoti dopo decodifica")
            return 0
        
        flags = raw_data[0]
        is_16bit = (flags & 0x01) != 0
        
        if is_16bit and len(raw_data) >= 3:
            heart_rate = (raw_data[2] << 8) | raw_data[1]
        elif len(raw_data) >= 2:
            heart_rate = raw_data[1]
        else:
            heart_rate = 0
        
        return heart_rate
        
    except Exception as e:
        print(f"❌ Errore decodifica heart rate: {e}")
        return 0

# ========== ROUTES ==========
# ========== ROUTES ==========

@app.route('/')
def index():
    return render_template('dashboard.html')

# API: Statistiche
@app.route('/api/stats')
def get_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT 
                AVG(heart_rate) as avg_bpm,
                MIN(heart_rate) as min_bpm,
                MAX(heart_rate) as max_bpm,
                COUNT(*) as total_samples
            FROM heart_rate_data
            WHERE timestamp > datetime('now', '-1 hour')
            AND heart_rate > 0
        ''')
        
        stats = cursor.fetchone()
        conn.close()
        
        return jsonify({
            'avg_bpm': round(stats['avg_bpm']) if stats['avg_bpm'] else 0,
            'min_bpm': stats['min_bpm'] if stats['min_bpm'] else 0,
            'max_bpm': stats['max_bpm'] if stats['max_bpm'] else 0,
            'total_samples': stats['total_samples']
        })
    except Exception as e:
        print(f"❌ Errore stats: {e}")
        return jsonify({
            'avg_bpm': 0,
            'min_bpm': 0,
            'max_bpm': 0,
            'total_samples': 0
        })

# API: Dati recenti
@app.route('/api/recent')
def get_recent_data():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT heart_rate, latitude, longitude, timestamp
            FROM heart_rate_data
            WHERE heart_rate > 0
            ORDER BY timestamp DESC
            LIMIT 50
        ''')
        
        rows = cursor.fetchall()
        conn.close()
        
        data = []
        for row in rows:
            data.append({
                'heart_rate': row['heart_rate'],
                'latitude': row['latitude'],
                'longitude': row['longitude'],
                'timestamp': row['timestamp']
            })
        
        data.reverse()
        return jsonify(data)
        
    except Exception as e:
        print(f"❌ Errore recent  {e}")
        return jsonify([])

# ========== ACTIVITY ENDPOINTS ==========

# API: Inizia attività
@app.route('/api/activity/start', methods=['POST'])
def start_activity():
    try:
        data = request.json
        device_id = data.get('device_id', 'unknown')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO activities (device_id, start_time, status)
            VALUES (?, datetime('now'), 'active')
        ''', (device_id,))
        
        activity_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        print(f"✅ Attività {activity_id} iniziata per {device_id}")
        
        return jsonify({
            'success': True,
            'activity_id': activity_id
        })
        
    except Exception as e:
        print(f"❌ Errore start activity: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# API: Aggiungi waypoint
@app.route('/api/activity/waypoint', methods=['POST'])
def add_waypoint():
    try:
        data = request.json
        activity_id = data.get('activity_id')
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        heart_rate = data.get('heart_rate', 0)
        
        if not activity_id or not latitude or not longitude:
            return jsonify({'success': False, 'error': 'Missing data'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO waypoints (activity_id, latitude, longitude, heart_rate)
            VALUES (?, ?, ?, ?)
        ''', (activity_id, latitude, longitude, heart_rate))
        
        conn.commit()
        conn.close()
        
        # Broadcast waypoint ai client web
        socketio.emit('new_waypoint', {
            'activity_id': activity_id,
            'latitude': latitude,
            'longitude': longitude,
            'heart_rate': heart_rate
        }, broadcast=True)
        
        return jsonify({'success': True})
        
    except Exception as e:
        print(f"❌ Errore waypoint: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# API: Termina attività
@app.route('/api/activity/stop', methods=['POST'])
def stop_activity():
    try:
        data = request.json
        activity_id = data.get('activity_id')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Calcola distanza totale
        cursor.execute('''
            SELECT latitude, longitude FROM waypoints
            WHERE activity_id = ?
            ORDER BY timestamp ASC
        ''', (activity_id,))
        
        waypoints = cursor.fetchall()
        distance_km = calculate_distance(waypoints)
        
        # Calcola statistiche HR
        cursor.execute('''
            SELECT AVG(heart_rate), COUNT(*)
            FROM waypoints
            WHERE activity_id = ? AND heart_rate > 0
        ''', (activity_id,))
        
        stats = cursor.fetchone()
        avg_hr = round(stats[0]) if stats[0] else 0
        
        # Durata in minuti
        cursor.execute('''
            SELECT 
                (julianday(datetime('now')) - julianday(start_time)) * 24 * 60 as duration_minutes
            FROM activities
            WHERE id = ?
        ''', (activity_id,))
        
        duration_minutes = cursor.fetchone()[0]
        
        # Velocità media (min/km)
        avg_speed = (duration_minutes / distance_km) if distance_km > 0 else 0
        
        # Calorie (formula approssimativa)
        calories = distance_km * 70
        
        # Aggiorna attività
        cursor.execute('''
            UPDATE activities
            SET end_time = datetime('now'),
                distance_km = ?,
                avg_speed = ?,
                avg_heart_rate = ?,
                calories = ?,
                status = 'completed'
            WHERE id = ?
        ''', (distance_km, avg_speed, avg_hr, calories, activity_id))
        
        conn.commit()
        conn.close()
        
        print(f"✅ Attività {activity_id} terminata: {distance_km:.2f}km, {avg_hr}bpm")
        
        return jsonify({
            'success': True,
            'distance_km': round(distance_km, 2),
            'avg_speed': round(avg_speed, 2),
            'avg_heart_rate': avg_hr,
            'calories': round(calories, 0),
            'duration_minutes': round(duration_minutes, 2)
        })
        
    except Exception as e:
        print(f"❌ Errore stop activity: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# API: Ottieni attività con waypoints
@app.route('/api/activity/<int:activity_id>')
def get_activity(activity_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Info attività
        cursor.execute('''
            SELECT * FROM activities WHERE id = ?
        ''', (activity_id,))
        
        activity = cursor.fetchone()
        
        if not activity:
            return jsonify({'error': 'Activity not found'}), 404
        
        # Waypoints
        cursor.execute('''
            SELECT latitude, longitude, heart_rate, timestamp
            FROM waypoints
            WHERE activity_id = ?
            ORDER BY timestamp ASC
        ''', (activity_id,))
        
        waypoints = []
        for row in cursor.fetchall():
            waypoints.append({
                'latitude': row[0],
                'longitude': row[1],
                'heart_rate': row[2],
                'timestamp': row[3]
            })
        
        conn.close()
        
        return jsonify({
            'id': activity['id'],
            'device_id': activity['device_id'],
            'start_time': activity['start_time'],
            'end_time': activity['end_time'],
            'distance_km': activity['distance_km'],
            'avg_speed': activity['avg_speed'],
            'avg_heart_rate': activity['avg_heart_rate'],
            'calories': activity['calories'],
            'status': activity['status'],
            'waypoints': waypoints
        })
        
    except Exception as e:
        print(f"❌ Errore get activity: {e}")
        return jsonify({'error': str(e)}), 500
# ========== SOCKET.IO HANDLERS ==========

@socketio.on('heart_rate_data')
def handle_heart_rate_data(data):
    try:
        device_id = data.get('device_id', 'unknown')
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        # Decodifica heart rate
        heart_rate = decode_heart_rate(data)
        
        print(f"📊 Device: {device_id}")
        print(f"   BPM: {heart_rate}")
        print(f"   GPS: {latitude}, {longitude}")
        
        # Salva SOLO se BPM > 0
        if heart_rate > 0:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO heart_rate_data (device_id, heart_rate, latitude, longitude)
                VALUES (?, ?, ?, ?)
            ''', (device_id, heart_rate, latitude, longitude))
            
            conn.commit()
            conn.close()
            
            # Invia ai client web
            emit('new_heart_rate', {
                'device_id': device_id,
                'heart_rate': heart_rate,
                'latitude': latitude,
                'longitude': longitude,
                'timestamp': datetime.now().isoformat()
            }, broadcast=True)
            
            print(f"✅ Dati salvati e inviati al web")
        else:
            print(f"⚠️ BPM = 0, dato ignorato")
        
    except Exception as e:
        print(f"❌ Errore handle_heart_rate_ {e}")
        import traceback
        traceback.print_exc()

@socketio.on('connect')
def handle_connect():
    print('✅ Client web connesso')

@socketio.on('disconnect')
def handle_disconnect():
    print('⚠️ Client web disconnesso')

# ========== MAIN ==========

# Inizializza database all'avvio
migrate_db()
init_db()
init_activities_db()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print('=' * 60)
    print('🚀 COOSPO Heart Rate Monitor Server')
    print('=' * 60)
    print(f'📡 Server su porta {port}')
    print('=' * 60)
    
    socketio.run(app, host='0.0.0.0', port=port, debug=True, allow_unsafe_werkzeug=True)
