from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import sqlite3
import base64
import os
from datetime import datetime

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

# Inizializza database
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

# Decodifica Heart Rate - VERSIONE CORRETTA
def decode_heart_rate(data):
    try:
        encoded_data = data.get('data', '')

        if not encoded_data:
            print("❌ Nessun campo 'data' nel messaggio")
            return 0

        # Decodifica da base64
        raw_data = base64.b64decode(encoded_data)

        if len(raw_data) == 0:
            print("❌ Dati vuoti dopo decodifica")
            return 0

        # Heart Rate Measurement Characteristic (0x2A37)
        flags = raw_data[0]
        is_16bit = (flags & 0x01) != 0

        if is_16bit and len(raw_data) >= 3:
            heart_rate = (raw_data[2] << 8) | raw_data[1]
        elif len(raw_data) >= 2:
            heart_rate = raw_data[1]
        else:
            heart_rate = 0

        print(f"✅ Heart rate decodificato: {heart_rate} bpm")
        return heart_rate

    except Exception as e:
        print(f"❌ Errore decodifica heart rate: {e}")
        print(f"   Dati ricevuti: {data}")
        return 0

# Route principale
@app.route('/')
def index():
    return render_template('dashboard.html')

# API endpoint per statistiche
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

# API endpoint per dati recenti
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
        print(f"❌ Errore recent: {e}")
        return jsonify([])

# Socket.IO: Ricevi dati dal device Flutter
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

        if heart_rate > 0:
            conn = get_db_connection()
            cursor = conn.cursor()

            cursor.execute('''
                INSERT INTO heart_rate_data (device_id, heart_rate, latitude, longitude)
                VALUES (?, ?, ?, ?)
            ''', (device_id, heart_rate, latitude, longitude))

            conn.commit()
            conn.close()

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
        print(f"❌ Errore handle_heart_rate_data: {e}")
        import traceback
        traceback.print_exc()

# Socket.IO: Connessione
@socketio.on('connect')
def handle_connect():
    print('✅ Client web connesso')

# Socket.IO: Disconnessione
@socketio.on('disconnect')
def handle_disconnect():
    print('⚠️ Client web disconnesso')

# Inizializza database all'avvio
migrate_db()
init_db()

# Avvia server
if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))

    print('=' * 60)
    print('🚀 COOSPO Heart Rate Monitor Server')
    print('=' * 60)
    print(f'📡 Server su porta {port}')
    print('=' * 60)

    socketio.run(app, host='0.0.0.0', port=port, debug=True, allow_unsafe_werkzeug=True)