import asyncio
import websockets
import base64
import json
import sqlite3
from datetime import datetime
import os

# Database setup
def init_database():
    conn = sqlite3.connect('heart_rate_data.db')
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS heart_rate (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            heart_rate INTEGER NOT NULL,
            device_id TEXT
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS rr_intervals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            rr_interval REAL NOT NULL,
            device_id TEXT
        )
    ''')
    
    conn.commit()
    conn.close()
    print("✅ Database inizializzato")

def decode_heart_rate(data_bytes):
    """Decodifica i dati Heart Rate secondo lo standard BLE"""
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

def save_to_database(heart_rate, rr_intervals, device_id="COOSPO"):
    """Salva i dati nel database"""
    conn = sqlite3.connect('heart_rate_data.db')
    cursor = conn.cursor()
    timestamp = datetime.now().isoformat()
    
    if heart_rate:
        cursor.execute(
            'INSERT INTO heart_rate (timestamp, heart_rate, device_id) VALUES (?, ?, ?)',
            (timestamp, heart_rate, device_id)
        )
    
    for rr in rr_intervals:
        cursor.execute(
            'INSERT INTO rr_intervals (timestamp, rr_interval, device_id) VALUES (?, ?, ?)',
            (timestamp, rr, device_id)
        )
    
    conn.commit()
    conn.close()

def calculate_statistics():
    """Calcola statistiche sui dati salvati"""
    conn = sqlite3.connect('heart_rate_data.db')
    cursor = conn.cursor()
    
    cursor.execute('SELECT AVG(heart_rate) FROM heart_rate')
    avg_hr = cursor.fetchone()[0]
    
    cursor.execute('SELECT MIN(heart_rate), MAX(heart_rate) FROM heart_rate')
    min_hr, max_hr = cursor.fetchone()
    
    cursor.execute('SELECT rr_interval FROM rr_intervals ORDER BY id')
    rr_values = [row[0] for row in cursor.fetchall()]
    
    hrv = None
    if len(rr_values) > 1:
        differences = [(rr_values[i+1] - rr_values[i])**2 for i in range(len(rr_values)-1)]
        hrv = (sum(differences) / len(differences)) ** 0.5
    
    conn.close()
    
    return {
        'avg_hr': round(avg_hr, 1) if avg_hr else 0,
        'min_hr': min_hr or 0,
        'max_hr': max_hr or 0,
        'hrv_rmssd': round(hrv, 2) if hrv else 0,
        'total_samples': len(rr_values)
    }

# Set per tenere traccia dei client dashboard
dashboard_clients = set()

async def dashboard_handler(websocket):
    """Handler per i client della dashboard web"""
    dashboard_clients.add(websocket)
    print(f"📊 Dashboard connessa (totale: {len(dashboard_clients)})")
    try:
        await websocket.wait_closed()
    finally:
        dashboard_clients.remove(websocket)
        print(f"📊 Dashboard disconnessa (totale: {len(dashboard_clients)})")

async def flutter_handler(websocket):
    """Handler per il client Flutter (BLE)"""
    print("✅ Cliente Flutter connesso")
    try:
        async for message in websocket:
            try:
                decoded_data = base64.b64decode(message)
                heart_rate, rr_intervals = decode_heart_rate(decoded_data)
                
                if heart_rate:
                    print(f"❤️  Heart Rate: {heart_rate} bpm")
                    if rr_intervals:
                        print(f"📊 RR Intervals: {rr_intervals} ms")
                    
                    save_to_database(heart_rate, rr_intervals)
                    
                    # Prepara dati da inviare
                    data_to_send = json.dumps({
                        'heart_rate': heart_rate,
                        'rr_intervals': rr_intervals,
                        'timestamp': datetime.now().isoformat()
                    })
                    
                    # Broadcast ai client dashboard
                    if dashboard_clients:
                        await asyncio.gather(
                            *[client.send(data_to_send) for client in dashboard_clients],
                            return_exceptions=True
                        )
                    
                    # Risposta al client Flutter
                    await websocket.send(data_to_send)
                    
            except Exception as e:
                print(f"❌ Errore decodifica: {e}")
                
    except websockets.exceptions.ConnectionClosed:
        print("⚠️  Cliente Flutter disconnesso")
    except Exception as e:
        print(f"❌ Errore: {e}")

async def handler(websocket):
    """Handler principale che smista i client"""
    # Controlla il primo messaggio per identificare il tipo di client
    try:
        first_message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
        
        # Se il primo messaggio è "dashboard", è un client dashboard
        if first_message == "dashboard":
            await dashboard_handler(websocket)
        else:
            # Altrimenti è un client Flutter, processa il primo messaggio
            try:
                decoded_data = base64.b64decode(first_message)
                heart_rate, rr_intervals = decode_heart_rate(decoded_data)
                
                if heart_rate:
                    print(f"❤️  Heart Rate: {heart_rate} bpm")
                    save_to_database(heart_rate, rr_intervals)
                    
                    data_to_send = json.dumps({
                        'heart_rate': heart_rate,
                        'rr_intervals': rr_intervals,
                        'timestamp': datetime.now().isoformat()
                    })
                    
                    if dashboard_clients:
                        await asyncio.gather(
                            *[client.send(data_to_send) for client in dashboard_clients],
                            return_exceptions=True
                        )
                    
                    await websocket.send(data_to_send)
            except:
                pass
            
            # Continua a gestire come client Flutter
            await flutter_handler(websocket)
            
    except asyncio.TimeoutError:
        # Timeout = probabilmente dashboard
        await dashboard_handler(websocket)
    except Exception as e:
        print(f"❌ Errore handler: {e}")

async def main():
    init_database()

    port = int(os.environ.get('PORT', 8765)) 
    async with websockets.serve(handler, "0.0.0.0", port):
        print("🚀 Server WebSocket in ascolto su porta {port}")
        print("📊 Database: heart_rate_data.db")
        print("🌐 Dashboard: connetti da browser con WebSocket")
        print("=" * 50)
        await asyncio.Future()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n📊 === STATISTICHE FINALI ===")
        stats = calculate_statistics()
        print(f"Media Heart Rate: {stats['avg_hr']} bpm")
        print(f"Min HR: {stats['min_hr']} bpm")
        print(f"Max HR: {stats['max_hr']} bpm")
        print(f"HRV (RMSSD): {stats['hrv_rmssd']} ms")
        print(f"Campioni totali: {stats['total_samples']}")
        print("=" * 50)
