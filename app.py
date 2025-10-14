import os
import asyncio
import base64
import json
import sqlite3
from datetime import datetime
from flask import Flask, render_template, jsonify
import websockets

app = Flask(__name__)

def init_database():
    """Inizializza il database SQLite"""
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
    """Decodifica i dati heart rate in base al tipo dispositivo"""
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
    """Salva i dati nel database"""
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

dashboard_clients = set()

async def dashboard_handler(websocket):
    """Gestisce connessioni dashboard"""
    dashboard_clients.add(websocket)
    print(f"📊 Dashboard connessa (totale: {len(dashboard_clients)})")
    try:
        await websocket.wait_closed()
    finally:
        dashboard_clients.remove(websocket)
        print(f"📊 Dashboard disconnessa (totale: {len(dashboard_clients)})")

async def flutter_handler(websocket, first_message=None):
    """Gestisce connessioni Flutter"""
    print("✅ Cliente Flutter connesso")
    
    if first_message:
        try:
            await process_message(first_message, websocket)
        except Exception as e:
            print(f"❌ Errore primo messaggio: {e}")
    
    try:
        async for message in websocket:
            await process_message(message, websocket)
    except websockets.exceptions.ConnectionClosed:
        print("⚠️  Cliente disconnesso")

async def process_message(message, websocket):
    """Processa messaggi ricevuti"""
    try:
        try:
            parsed = json.loads(message)
            device_type = parsed.get("device_type", "unknown")
            device_id = parsed.get("device_id", "COOSPO")
            data_b64 = parsed.get("data", message)
            decoded_data = base64.b64decode(data_b64)
        except (json.JSONDecodeError, KeyError):
            device_type = "unknown"
            device_id = "COOSPO"
            decoded_data = base64.b64decode(message)
        
        heart_rate, rr_intervals = decode_heart_rate(device_type, decoded_data)
        
        if heart_rate:
            print(f"❤️  {heart_rate} bpm | Device: {device_type}")
            save_to_database(heart_rate, rr_intervals, device_id, device_type)
            
            data_to_send = json.dumps({
                'heart_rate': heart_rate,
                'rr_intervals': rr_intervals,
                'timestamp': datetime.now().isoformat(),
                'device_type': device_type,
                'device_id': device_id
            })
            
            if dashboard_clients:
                await asyncio.gather(
                    *[client.send(data_to_send) for client in dashboard_clients],
                    return_exceptions=True
                )
            
            await websocket.send(data_to_send)
    
    except Exception as e:
        print(f"❌ Errore: {e}")

async def handler(websocket):
    """Handler principale WebSocket"""
    try:
        first_message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
        
        if first_message == "dashboard":
            await dashboard_handler(websocket)
        else:
            await flutter_handler(websocket, first_message)
    
    except asyncio.TimeoutError:
        await dashboard_handler(websocket)

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

async def websocket_server():
    """Avvia il server WebSocket"""
    port = int(os.environ.get('PORT', 10000))
    print(f"🚀 WebSocket server porta {port}")
    async with websockets.serve(handler, "0.0.0.0", port):
        await asyncio.Future()

if __name__ == '__main__':
    init_database()
    asyncio.run(websocket_server())
