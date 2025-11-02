import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance; // Singleton
  BluetoothService._internal();

  final Map<String, StreamSubscription> _connectionSubscriptions = {}; // Subscription connessioni
  final Map<String, BluetoothDevice> _connectedDevices = {}; // Dispositivi connessi

  // Controlla se ci sono dispositivi connessi
  bool get hasConnectedDevices => _connectedDevices.isNotEmpty;
  List<BluetoothDevice> get connectedDevices => _connectedDevices.values.toList();

  // Connette a dispositivo BLE con tentativi e timeout
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan(); // Ferma scansione attiva
      await Future.delayed(const Duration(milliseconds: 300));

      await _cleanupExistingConnection(device); // Pulisce connessioni precedenti

      final initialState = await device.connectionState.first;
      if (initialState == BluetoothConnectionState.connected) {
        print('✅ Dispositivo già connesso');
        _setupConnectionMonitoring(device); // Monitora connessione
        return true;
      }

      print('🔌 Connessione a ${device.platformName}...');
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Attende conferma connessione con max 10 tentativi
      bool connected = false;
      int attempts = 0;
      while (!connected && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        final currentState = await device.connectionState.first;
        if (currentState == BluetoothConnectionState.connected) {
          connected = true;
          break;
        }
        attempts++;
      }

      if (!connected) {
        throw Exception('Timeout: dispositivo non risponde');
      }

      print('✅ Dispositivo connesso');

      await device.discoverServices(); // Scopri servizi

      _setupConnectionMonitoring(device); // Monitora connessione

      return true;
    } catch (e) {
      print('❌ Errore connessione: $e');
      try {
        await device.disconnect(); // Disconnetti in caso di errore
      } catch (_) {}
      return false;
    }
  }

  // Disconnette dispositivo con timeout forzato
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    print('🔴 Disconnessione ${device.platformName}...');
    
    try {
      await device.disconnect(timeout: 5).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Timeout disconnessione - forzando chiusura');
        },
      );
      print('✅ Disconnesso');
    } catch (e) {
      print('⚠️ Errore disconnect (ignorato): $e');
    } finally {
      _cleanupDevice(device); // Pulisce risorse
    }
  }

  // Pulisce connessioni esistenti prima di nuova connessione
  Future<void> _cleanupExistingConnection(BluetoothDevice device) async {
    try {
      await _connectionSubscriptions[device.remoteId.str]?.cancel(); // Cancella subscription
      _connectionSubscriptions.remove(device.remoteId.str);

      if (_connectedDevices.containsKey(device.remoteId.str)) {
        try {
          await device.disconnect().timeout(const Duration(seconds: 2)); // Disconnetti se connesso
        } catch (_) {}
        _connectedDevices.remove(device.remoteId.str);
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  // Monitora stato connessione del dispositivo
  void _setupConnectionMonitoring(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str] = device.connectionState.listen(
      (state) {
        print('📡 Stato connessione ${device.platformName}: $state');
        
        if (state == BluetoothConnectionState.disconnected) {
          print('⚠️ Dispositivo disconnesso');
          _cleanupDevice(device); // Pulisce risorse su disconnessione
        }
      },
      onError: (error) {
        print('❌ Errore stato connessione: $error');
        _cleanupDevice(device); // Pulisce risorse su errore
      },
    );
    
    _connectedDevices[device.remoteId.str] = device; // Aggiunge dispositivo connesso
  }

  // Pulisce risorse associate al dispositivo
  void _cleanupDevice(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str]?.cancel();
    _connectionSubscriptions.remove(device.remoteId.str);
    _connectedDevices.remove(device.remoteId.str);
  }

  // Verifica se dispositivo è connesso
  bool isDeviceConnected(BluetoothDevice device) {
    return _connectedDevices.containsKey(device.remoteId.str);
  }

  // Pulisce tutte le connessioni (da chiamare in dispose app)
  void dispose() {
    print('🧹 Pulizia BluetoothService...');
    
    for (var device in _connectedDevices.values) {
      try {
        device.disconnect();
      } catch (_) {}
    }
    
    for (var sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    
    _connectionSubscriptions.clear();
    _connectedDevices.clear();
  }
}