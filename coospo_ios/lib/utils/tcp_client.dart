import 'dart:io';
import 'dart:convert';

class TCPDataSender {
  Socket? _socket;
  final String host = 'lambda-iot.uniud.it';
  final int port = 25000;
  bool _isConnected = false;

  Future<bool> connect() async {
    try {
      _socket = await Socket.connect(
        host, 
        port, 
        timeout: Duration(seconds: 5)
      );
      _isConnected = true;
      print('✅ Connesso a TCP server $host:$port');
      return true;
    } catch (e) {
      print('❌ Errore connessione TCP: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> sendData(String sensorName, Map<String, dynamic> data) async {
    if (!_isConnected) {
      bool connected = await connect();
      if (!connected) return;
    }

    try {
      final payload = {
        'timestamp': DateTime.now().toIso8601String(),
        'sensor_name': sensorName,
        ...data
      };

      final jsonLine = jsonEncode(payload) + '\n';
      _socket?.write(jsonLine);
      await _socket?.flush();
      
      print('📤 Inviato a TCP server: $sensorName');
    } catch (e) {
      print('❌ Errore invio TCP: $e');
      _isConnected = false;
      _socket = null;
    }
  }

  void disconnect() {
    try {
      _socket?.close();
    } catch (e) {
      print('⚠️ Errore disconnessione: $e');
    }
    _socket = null;
    _isConnected = false;
    print('🔌 Disconnesso da TCP server');
  }

  bool get isConnected => _isConnected;
}
