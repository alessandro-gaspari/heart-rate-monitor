import os
import asyncio
import base64
import json
import sqlite3
from datetime import datetime
from flask import Flask, render_template, jsonify
import websockets

app = Flask(__name__)

# ... funzioni init_database, decode_heart_rate, save_to_database uguali ...

dashboard_clients = set()

async def dashboard_handler(websocket):
    dashboard_clients.add(websocket)
    print(f"📊 Dashboard connessa")
    try:
        await websocket.wait_closed()
    finally:
        dashboard_clients.remove(websocket)

async def flutter_handler(websocket, first_message=None):
    print("✅ Cliente Flutter connesso")
    
    if first_message:
        try:
            await process_message(first_message, websocket)
        except Exception as e:
            print(f"❌ Errore: {e}")
    
    try:
        async for message in websocket:
            await process_message(message, websocket)
    except websockets.exceptions.ConnectionClosed:
        print("⚠️ Cliente disconnesso")

async def process_message(message, websocket):
    try:
        try:
            parsed = json.loads(message)
            device_type = parsed.get("device_type", "unknown")
            device_id = parsed.get("device_id", "COOSPO")
            data_b64 = parsed.get("data", message)
            decoded_data = base64.b64decode(data_b64)
        except:
            device_type = "unknown"
            device_id = "COOSPO"
            decoded_data = base64.b64decode(message)
        
        heart_rate, rr_intervals = decode_heart_rate(device_type, decoded_data)
        
        if heart_rate:
            print(f"❤️ {heart_rate} bpm")
            save_to_database(heart_rate, rr_intervals, device_id, device_type)
            
            data_to_send = json.dumps({
                'heart_rate': heart_rate,
                'rr_intervals': rr_intervals,
                'timestamp': datetime.now().isoformat(),
                'device_type': device_type,
                'device_id': device_id
            })
            
            if dashboard_clients:
                await asyncio.gather(*[client.send(data_to_send) for client in dashboard_clients], return_exceptions=True)
            
            await websocket.send(data_to_send)
    except Exception as e:
        print(f"❌ Errore: {e}")

async def handler(websocket):
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
    # ... uguale a prima ...
    pass

@app.route('/api/history/<int:minutes>')
def get_history(minutes):
    # ... uguale a prima ...
    pass

# WEBSOCKET SERVER - STESSA PORTA
async def websocket_server():
    port = int(os.environ.get('PORT', 10000))
    print(f"🚀 WebSocket server porta {port}")
    async with websockets.serve(handler, "0.0.0.0", port):
        await asyncio.Future()

if __name__ == '__main__':
    init_database()
    # Avvia solo WebSocket (Render non supporta Flask + WebSocket insieme)
    asyncio.run(websocket_server())
