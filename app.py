from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
from flask_cors import CORS
import base64
from datetime import datetime
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = 'coospo_heart_rate_monitor_secret_2024'
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Storage solo temporaneo in memoria (RAM, fino a massimo 200 dati recenti)
recent_data = []
MAX_RECENT_DATA = 200

# Decodifica dati heart rate da base64
def decode_heart_rate(data):
    try:
        encoded_data = data.get('data', '')
        if not encoded_data:
            return 0
        raw_data = base64.b64decode(encoded_data)
        if len(raw_data) == 0:
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

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/api/stats')
def get_stats():
    try:
        if not recent_data:
            return jsonify({'avg_bpm': 0, 'min_bpm': 0, 'max_bpm': 0, 'total_samples': 0})
        heart_rates = [d['heart_rate'] for d in recent_data if d['heart_rate'] > 0]
        if not heart_rates:
            return jsonify({'avg_bpm': 0, 'min_bpm': 0, 'max_bpm': 0, 'total_samples': 0})
        return jsonify({
            'avg_bpm': round(sum(heart_rates) / len(heart_rates)),
            'min_bpm': min(heart_rates),
            'max_bpm': max(heart_rates),
            'total_samples': len(heart_rates)
        })
    except Exception as e:
        print(f"❌ Errore stats: {e}")
        return jsonify({'avg_bpm': 0, 'min_bpm': 0, 'max_bpm': 0, 'total_samples': 0})

@app.route('/api/recent')
def get_recent_data():
    try:
        return jsonify(recent_data[-50:])
    except Exception as e:
        print(f"❌ Errore recent: {e}")
        return jsonify([])

@socketio.on('heart_rate_data')
def handle_heart_rate_data(data):
    try:
        # Preleva tutte le info utili
        device_id = data.get('device_id', 'unknown')
        device_name = data.get('device_name', 'unknown')
        device_type = data.get('device_type', 'unknown')
        user_id = data.get('user_id')
        user_name = data.get('user_name')
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        heart_rate = decode_heart_rate(data)

        print("=" * 60)
        print(f"Ricevuto da {device_name}: BPM={heart_rate}, User={user_name}, GPS=({latitude},{longitude})")
        print("=" * 60)

        if heart_rate > 0:
            data_point = {
                'device_id': device_id,
                'device_name': device_name,
                'device_type': device_type,
                'heart_rate': heart_rate,
                'latitude': latitude,
                'longitude': longitude,
                'user_id': user_id,
                'user_name': user_name,
                'timestamp': datetime.now().isoformat()
            }
            recent_data.append(data_point)
            if len(recent_data) > MAX_RECENT_DATA:
                recent_data.pop(0)
            emit('new_heart_rate', data_point, broadcast=True)
        else:
            print("⚠️ BPM=0 ignorato")
    except Exception as e:
        print(f"❌ Errore heart_rate_ {e}")

@socketio.on('connect')
def handle_connect():
    print('✅ Client web connesso')
    emit('recent_data', recent_data[-50:])

@socketio.on('disconnect')
def handle_disconnect():
    print('⚠️ Client web disconnesso')

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    print("=" * 60)
    print("🚀 COOSPO Heart Rate Monitor Server - Render Edition (NO DB)")
    print("=" * 60)
    print(f"📡 Listening on port {port}")
    print('📊 Dati recenti (RAM): massimi', MAX_RECENT_DATA)
    print('💾 Persistenza vera SOLO su server SSH')
    print("=" * 60)
    socketio.run(app, host='0.0.0.0', port=port, debug=True, allow_unsafe_werkzeug=True)
