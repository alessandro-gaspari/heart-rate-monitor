import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothConnectionService {
  static final BluetoothConnectionService _instance = BluetoothConnectionService._internal();
  factory BluetoothConnectionService() => _instance;
  BluetoothConnectionService._internal();

  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  final Map<String, BluetoothDevice> _connectedDevices = {};
  
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Cleanup any existing connection
      await _cleanupExistingConnection(device);

      bool connected = false;
      int attempts = 0;
      const maxAttempts = 3;
      const connectionTimeout = Duration(seconds: 30);

      while (!connected && attempts < maxAttempts) {
        attempts++;
        print('Tentativo di connessione ${attempts}/${maxAttempts}');

        try {
          // Tentativo di connessione con timeout esteso
          await device.connect(
            timeout: connectionTimeout,
            autoConnect: false,
          ).timeout(
            connectionTimeout,
            onTimeout: () => throw TimeoutException('Timeout connessione dopo ${connectionTimeout.inSeconds}s'),
          );

          // Verifica dello stato di connessione
          await Future.delayed(const Duration(seconds: 2));
          final state = await device.connectionState.first;
          
          if (state == BluetoothConnectionState.connected) {
            print('Dispositivo connesso, verifico servizi...');
            
            // Scoperta servizi con retry
            List<BluetoothService> services = [];
            int serviceAttempts = 0;
            while (services.isEmpty && serviceAttempts < 3) {
              try {
                services = await device.discoverServices();
                if (services.isNotEmpty) {
                  print('Trovati ${services.length} servizi');
                  connected = true;
                  _setupConnectionMonitoring(device);
                  break;
                }
              } catch (e) {
                print('Errore scoperta servizi: $e');
                serviceAttempts++;
                if (serviceAttempts < 3) {
                  await Future.delayed(const Duration(seconds: 1));
                }
              }
            }

            if (services.isEmpty) {
              throw Exception('Nessun servizio trovato dopo $serviceAttempts tentativi');
            }
          }
        } catch (e) {
          print('Errore connessione: $e');
          await device.disconnect();
          if (attempts < maxAttempts) {
            print('Attendo prima del prossimo tentativo...');
            await Future.delayed(const Duration(seconds: 3));
          }
        }
      }

      if (!connected) {
        throw Exception('Impossibile stabilire la connessione dopo $maxAttempts tentativi');
      }

      return connected;
    } catch (e) {
      print('Errore fatale durante la connessione: $e');
      await disconnectFromDevice(device);
      return false;
    }
  }

  Future<void> _cleanupExistingConnection(BluetoothDevice device) async {
    try {
      // Cancella eventuali sottoscrizioni esistenti
      await _connectionSubscriptions[device.remoteId.str]?.cancel();
      _connectionSubscriptions.remove(device.remoteId.str);
      
      // Assicurati che il dispositivo sia disconnesso
      if (_connectedDevices.containsKey(device.remoteId.str)) {
        await device.disconnect();
        _connectedDevices.remove(device.remoteId.str);
      }
      
      // Attendi che la disconnessione sia completata
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      print('Errore durante la pulizia della connessione: $e');
    }
  }

  void _setupConnectionMonitoring(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str] = device.connectionState.listen(
      (BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          print('Dispositivo disconnesso: ${device.remoteId.str}');
          _cleanupDevice(device);
        }
      },
      onError: (error) {
        print('Errore monitoraggio connessione: $error');
        _cleanupDevice(device);
      }
    );

    _connectedDevices[device.remoteId.str] = device;
  }

  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      print('Errore durante la disconnessione: $e');
    } finally {
      _cleanupDevice(device);
    }
  }

  void _cleanupDevice(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str]?.cancel();
    _connectionSubscriptions.remove(device.remoteId.str);
    _connectedDevices.remove(device.remoteId.str);
  }

  bool isDeviceConnected(BluetoothDevice device) {
    return _connectedDevices.containsKey(device.remoteId.str);
  }

  void dispose() {
    for (var device in _connectedDevices.values) {
      disconnectFromDevice(device);
    }
    for (var subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();
    _connectedDevices.clear();
  }
}