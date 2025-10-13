import asyncio
import websockets

async def test():
    uri = "ws://localhost:8765"
    async with websockets.connect(uri) as websocket:
        await websocket.send("Prova WebSocket!")
        print("Messaggio inviato e connessione funzionante!")

asyncio.run(test())
