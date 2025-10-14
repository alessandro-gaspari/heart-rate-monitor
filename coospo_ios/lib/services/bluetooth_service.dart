import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  final Map<String, BluetoothDevice> _connectedDevices = {};

  // Verifica se ci sono dispositivi connessi
  bool get hasConnectedDevices => _connectedDevices.isNotEmpty;
  List<BluetoothDevice> get connectedDevices => _connectedDevices.values.toList();

  /// Connette a un dispositivo BLE con retry automatico
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Ferma scansione se attiva
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 300));

      // Pulisci eventuali connessioni precedenti
      await _cleanupExistingConnection(device);

      // Verifica se già connesso
      final initialState = await device.connectionState.first;
      if (initialState == BluetoothConnectionState.connected) {
        print('✅ Dispositivo già connesso');
        _setupConnectionMonitoring(device);
        return true;
      }

      // Connetti con timeout
      print('🔌 Connessione a ${device.platformName}...');
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Attendi conferma connessione
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

      // Scopri servizi (importante per mantenere connessione stabile)
      await device.discoverServices();

      // Monitora connessione
      _setupConnectionMonitoring(device);

      return true;
    } catch (e) {
      print('❌ Errore connessione: $e');
      try {
        await device.disconnect();
      } catch (_) {}
      return false;
    }
  }

  /// Disconnette un dispositivo BLE con pulizia forzata
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    print('🔴 Disconnessione ${device.platformName}...');
    
    try {
      // Disconnetti con timeout forzato
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
      _cleanupDevice(device);
    }
  }

  /// Pulisce connessioni esistenti prima di riconnettere
  Future<void> _cleanupExistingConnection(BluetoothDevice device) async {
    try {
      // Cancella subscription precedente
      await _connectionSubscriptions[device.remoteId.str]?.cancel();
      _connectionSubscriptions.remove(device.remoteId.str);

      // Se già connesso, disconnetti
      if (_connectedDevices.containsKey(device.remoteId.str)) {
        try {
          await device.disconnect().timeout(const Duration(seconds: 2));
        } catch (_) {}
        _connectedDevices.remove(device.remoteId.str);
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  /// Monitora lo stato della connessione
  void _setupConnectionMonitoring(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str] = device.connectionState.listen(
      (state) {
        print('📡 Stato connessione ${device.platformName}: $state');
        
        if (state == BluetoothConnectionState.disconnected) {
          print('⚠️ Dispositivo disconnesso');
          _cleanupDevice(device);
        }
      },
      onError: (error) {
        print('❌ Errore stato connessione: $error');
        _cleanupDevice(device);
      },
    );
    
    _connectedDevices[device.remoteId.str] = device;
  }

  /// Pulisce risorse di un dispositivo
  void _cleanupDevice(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str]?.cancel();
    _connectionSubscriptions.remove(device.remoteId.str);
    _connectedDevices.remove(device.remoteId.str);
  }

  /// Verifica se un dispositivo è connesso
  bool isDeviceConnected(BluetoothDevice device) {
    return _connectedDevices.containsKey(device.remoteId.str);
  }

  /// Pulisce tutte le connessioni (chiamare in dispose dell'app)
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
