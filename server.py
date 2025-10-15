import asyncio
import base64
import json
import sqlite3
from datetime import datetime
import websockets

# Database setup
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

def decode_heart_rate(device_type, data_bytes):
    """Decodifica i dati in base al tipo di dispositivo"""
    if device_type == 'heartRateBand':
        # Decodifica standard Heart Rate Band
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
        # Decodifica per Armband (esempio - adatta secondo il tuo dispositivo)
        if len(data_bytes) >= 2:
            heart_rate = data_bytes[1]
            return heart_rate, []
        return None, []
    
    else:
        # Default fallback - prova decodifica standard
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

# Set per tenere traccia dei client dashboard connessi
dashboard_clients = set()

async def dashboard_handler(websocket):
    """Gestisce connessioni dalla dashboard web"""
    dashboard_clients.add(websocket)
    print(f"📊 Dashboard connessa (totale: {len(dashboard_clients)})")
    try:
        await websocket.wait_closed()
    finally:
        dashboard_clients.remove(websocket)
        print(f"📊 Dashboard disconnessa (totale: {len(dashboard_clients)})")

async def flutter_handler(websocket, first_message=None):
    """Gestisce connessioni dall'app Flutter"""
    print("✅ Cliente Flutter connesso")
    
    # Processa il primo messaggio se presente
    if first_message:
        try:
            await process_message(first_message, websocket)
        except Exception as e:
            print(f"❌ Errore elaborazione primo messaggio: {e}")
    
    try:
        async for message in websocket:
            await process_message(message, websocket)
    except websockets.exceptions.ConnectionClosed:
        print("⚠️  Cliente Flutter disconnesso")

async def process_message(message, websocket):
    """Processa un messaggio ricevuto dal client"""
    try:
        # Prova a parsare come JSON con device_type
        try:
            parsed = json.loads(message)
            device_type = parsed.get("device_type", "unknown")
            device_id = parsed.get("device_id", "COOSPO")
            data_b64 = parsed.get("data", message)
            decoded_data = base64.b64decode(data_b64)
        except (json.JSONDecodeError, KeyError):
            # Fallback: messaggio è solo base64
            device_type = "unknown"
            device_id = "COOSPO"
            decoded_data = base64.b64decode(message)
        
        heart_rate, rr_intervals = decode_heart_rate(device_type, decoded_data)
        
        if heart_rate:
            print(f"❤️  Heart Rate: {heart_rate} bpm | Device: {device_type}")
            save_to_database(heart_rate, rr_intervals, device_id, device_type)
            
            # Prepara dati da inviare
            data_to_send = json.dumps({
                'heart_rate': heart_rate,
                'rr_intervals': rr_intervals,
                'timestamp': datetime.now().isoformat(),
                'device_type': device_type,
                'device_id': device_id
            })
            
            # Invia alla dashboard
            if dashboard_clients:
                await asyncio.gather(
                    *[client.send(data_to_send) for client in dashboard_clients],
                    return_exceptions=True
                )
            
            # Risposta al client Flutter
            await websocket.send(data_to_send)
    
    except Exception as e:
        print(f"❌ Errore elaborazione messaggio: {e}")

async def handler(websocket, path):
    """Handler principale per connessioni WebSocket"""
    try:
        # Attendi il primo messaggio per distinguere il tipo di client
        first_message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
        
        if first_message == "dashboard":
            # Client è una dashboard
            await dashboard_handler(websocket)
        else:
            # Client è Flutter o altro
            await flutter_handler(websocket, first_message)
    
    except asyncio.TimeoutError:
        # Timeout: probabilmente una dashboard
        await dashboard_handler(websocket)
    
    except Exception as e:
        print(f"❌ Errore handler: {e}")

async def main():
    """Avvia il server WebSocket"""
    init_database()
    
    # Porta per il WebSocket
    port = 8765
    print(f"🚀 Server WebSocket avviato sulla porta {port}")
    
    async with websockets.serve(handler, "0.0.0.0", port):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())