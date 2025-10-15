import os
import base64
import json
import sqlite3
from datetime import datetime
from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO, emit

app = Flask(__name__)
app.config['SECRET_KEY'] = 'heart-rate-monitor-secret'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

def init_database():
    conn = sqlite3.connect('heart_rate_data.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS heart_rate (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            heart_rate INTEGER NOT NULL,
            device_id TEXT,
            device_type TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS rr_intervals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            rr_interval REAL NOT NULL,
            device_id TEXT,
            device_type TEXT
        )
    ''')
    conn.commit()
    conn.close()
    print("✅ Database inizializzato")

def decode_heart_rate(device_type, data_bytes):
    if device_type == 'heartRateBand':
        if len(data_bytes) < 2:
            return None, []
        flags = data_bytes[0]
        heart_rate_format = flags & 0x01
        rr_interval_present = (flags >> 4) & 0x01
        
        if heart_rate_format == 0:
            heart_rate = data_bytes[1]
            offset = 2
        else:
            if len(data_bytes) < 3:
                return None, []
            heart_rate = int.from_bytes(data_bytes[1:3], 'little')
            offset = 3
        
        rr_intervals = []
        if rr_interval_present:
            for i in range(offset, len(data_bytes), 2):
                if i + 1 < len(data_bytes):
                    rr_value = int.from_bytes(data_bytes[i:i+2], 'little')
                    rr_ms = rr_value * 1000 / 1024
                    rr_intervals.append(round(rr_ms, 2))
        
        return heart_rate, rr_intervals
    
    elif device_type == 'armband':
        if len(data_bytes) >= 2:
            heart_rate = data_bytes[1]
            return heart_rate, []
        return None, []
    
    else:
        if len(data_bytes) < 2:
            return None, []
        flags = data_bytes[0]
        heart_rate_format = flags & 0x01
        
        if heart_rate_format == 0:
            heart_rate = data_bytes[1]
        else:
            if len(data_bytes) < 3:
                return None, []
            heart_rate = int.from_bytes(data_bytes[1:3], 'little')
        
        return heart_rate, []

def save_to_database(heart_rate, rr_intervals, device_id="COOSPO", device_type="unknown"):
    conn = sqlite3.connect('heart_rate_data.db')
    cursor = conn.cursor()
    timestamp = datetime.now().isoformat()
    
    if heart_rate:
        cursor.execute(
            'INSERT INTO heart_rate (timestamp, heart_rate, device_id, device_type) VALUES (?, ?, ?, ?)',
            (timestamp, heart_rate, device_id, device_type)
        )
    
    for rr in rr_intervals:
        cursor.execute(
            'INSERT INTO rr_intervals (timestamp, rr_interval, device_id, device_type) VALUES (?, ?, ?, ?)',
            (timestamp, rr, device_id, device_type)
        )
    
    conn.commit()
    conn.close()

# Routes Flask
@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/statistics')
def get_statistics():
    conn = sqlite3.connect('heart_rate_data.db')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute('SELECT COUNT(*) as total, AVG(heart_rate) as avg, MIN(heart_rate) as min, MAX(heart_rate) as max FROM heart_rate')
    stats = cursor.fetchone()
    
    cursor.execute('SELECT device_type, COUNT(*) as count FROM heart_rate GROUP BY device_type')
    device_stats = cursor.fetchall()
    
    conn.close()
    
    return jsonify({
        'total_samples': stats['total'] or 0,
        'avg_hr': round(stats['avg'], 1) if stats['avg'] else 0,
        'min_hr': stats['min'] or 0,
        'max_hr': stats['max'] or 0,
        'device_types': [{'type': row['device_type'], 'count': row['count']} for row in device_stats]
    })

@app.route('/api/history/<int:minutes>')
def get_history(minutes):
    conn = sqlite3.connect('heart_rate_data.db')
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute('SELECT timestamp, heart_rate, device_type FROM heart_rate ORDER BY timestamp DESC LIMIT ?', (minutes * 12,))
    data = [{'timestamp': row['timestamp'], 'heart_rate': row['heart_rate'], 'device_type': row['device_type']} for row in cursor.fetchall()]
    
    conn.close()
    return jsonify(data)

# SocketIO events
@socketio.on('connect')
def handle_connect():
    print('✅ Client connesso')

@socketio.on('disconnect')
def handle_disconnect():
    print('⚠️  Client disconnesso')

@socketio.on('dashboard')
def handle_dashboard():
    print('📊 Dashboard connessa')

@socketio.on('heart_rate_data')
def handle_heart_rate_data(data):
    try:
        device_id = data.get('device_id', 'unknown')
        heart_rate = decode_heart_rate(data)
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
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
        
        print(f"✅ BPM: {heart_rate}, GPS: {latitude}, {longitude}")
        
    except Exception as e:
        print(f"❌ Errore: {e}")


if __name__ == '__main__':
    init_database()
    port = int(os.environ.get('PORT', 10000))
    print(f"🚀 Server avviato sulla porta {port}")
    socketio.run(app, host='0.0.0.0', port=port, debug=False, allow_unsafe_werkzeug=True)

