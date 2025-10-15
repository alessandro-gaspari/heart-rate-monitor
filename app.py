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
        
        # Controlla se le colonne esistono
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

# Decodifica Heart Rate dal dato BLE
def decode_heart_rate(data):
    try:
        # Decodifica base64
        raw_data = base64.b64decode(data.get('data', ''))
        
        if not raw_:
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
        
        return heart_rate
    except Exception as e:
        print(f"❌ Errore decodifica: {e}")
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
        
        # Calcola statistiche dell'ultima ora
        cursor.execute('''
            SELECT 
                AVG(heart_rate) as avg_bpm,
                MIN(heart_rate) as min_bpm,
                MAX(heart_rate) as max_bpm,
                COUNT(*) as total_samples
            FROM heart_rate_data
            WHERE timestamp > datetime('now', '-1 hour')
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

# API endpoint per dati recenti (ultimi 50)
@app.route('/api/recent')
def get_recent_data():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Ultimi 50 dati
        cursor.execute('''
            SELECT heart_rate, latitude, longitude, timestamp
            FROM heart_rate_data
            ORDER BY timestamp DESC
            LIMIT 50
        ''')
        
        rows = cursor.fetchall()
        conn.close()
        
        # Converti in lista di dict
        data = []
        for row in rows:
            data.append({
                'heart_rate': row['heart_rate'],
                'latitude': row['latitude'],
                'longitude': row['longitude'],
                'timestamp': row['timestamp']
            })
        
        # Inverti l'ordine (dal più vecchio al più recente per il grafico)
        data.reverse()
        
        return jsonify(data)
    except Exception as e:
        print(f"❌ Errore recent  {e}")
        return jsonify([])

# Socket.IO: Ricevi dati dal device Flutter
@socketio.on('heart_rate_data')
def handle_heart_rate_data(data):
    try:
        device_id = data.get('device_id', 'unknown')
        heart_rate = decode_heart_rate(data)
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        print(f"📊 Ricevuto - Device: {device_id}, BPM: {heart_rate}, GPS: {latitude}, {longitude}")
        
        # Salva nel database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO heart_rate_data (device_id, heart_rate, latitude, longitude)
            VALUES (?, ?, ?, ?)
        ''', (device_id, heart_rate, latitude, longitude))
        
        conn.commit()
        conn.close()
        
        # Invia ai client web connessi
        emit('new_heart_rate', {
            'device_id': device_id,
            'heart_rate': heart_rate,
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': datetime.now().isoformat()
        }, broadcast=True)
        
        print(f"✅ Dati salvati e inviati ai client web")
        
    except Exception as e:
        print(f"❌ Errore handle_heart_rate_ {e}")

# Socket.IO: Connessione client
@socketio.on('connect')
def handle_connect():
    print('✅ Client web connesso')

# Socket.IO: Disconnessione client
@socketio.on('disconnect')
def handle_disconnect():
    print('⚠️ Client web disconnesso')

# Inizializza database all'avvio
migrate_db()
init_db()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    
    print('=' * 60)
    print('🚀 COOSPO Heart Rate Monitor Server')
    print('=' * 60)
    print(f'📡 Server in ascolto su porta {port}')
    print('=' * 60)
    
    socketio.run(app, host='0.0.0.0', port=port, debug=False, allow_unsafe_werkzeug=True)
