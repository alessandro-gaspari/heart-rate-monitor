import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothManager {
  static final BluetoothManager _instance = BluetoothManager._internal();
  factory BluetoothManager() => _instance;
  BluetoothManager._internal();

  final Map<String, StreamSubscription> _connectionSubscriptions = {};

  Future<bool> connect(BluetoothDevice device) async {
    bool connected = false;
    try {
      // Disconnetti prima di riconnettere
      await device.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));

      // Connetti con retry
      int retryCount = 0;
      while (!connected && retryCount < 3) {
        try {
          await device.connect(
            timeout: const Duration(seconds: 5),
            autoConnect: false,
          );
          
          // Verifica che il dispositivo sia effettivamente connesso
          if (device.isConnected) {
            connected = true;
            
            // Scopri i servizi
            final services = await device.discoverServices();
            if (services.isEmpty) {
              throw Exception('Nessun servizio trovato');
            }
            
            // Monitora lo stato della connessione
            _connectionSubscriptions[device.remoteId.str] = device.connectionState.listen((state) {
              if (state == BluetoothConnectionState.disconnected) {
                _cleanup(device);
              }
            });
          }
        } catch (e) {
          retryCount++;
          if (retryCount < 3) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
    } catch (e) {
      print('Errore di connessione: $e');
      await disconnect(device);
      return false;
    }
    return connected;
  }

  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      print('Errore durante la disconnessione: $e');
    } finally {
      _cleanup(device);
    }
  }

  void _cleanup(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str]?.cancel();
    _connectionSubscriptions.remove(device.remoteId.str);
  }

  void dispose() {
    for (var subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();
  }
}