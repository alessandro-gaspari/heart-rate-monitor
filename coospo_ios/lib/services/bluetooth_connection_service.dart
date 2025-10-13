import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothConnectionService {
  static final BluetoothConnectionService _instance =
      BluetoothConnectionService._internal();
  factory BluetoothConnectionService() => _instance;
  BluetoothConnectionService._internal();

  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, StreamSubscription<List<int>>> _characteristicSubscriptions = {};

  bool _maintainConnectionInBackground = true;

  bool get hasConnectedDevices => _connectedDevices.isNotEmpty;
  List<BluetoothDevice> get connectedDevices => _connectedDevices.values.toList();

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 500));

      // Pulisci connessioni precedenti
      await _cleanupExistingConnection(device);

      final initialState = await device.connectionState.first;
      if (initialState == BluetoothConnectionState.connected) {
        _setupConnectionMonitoring(device);
        return true;
      }

      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);

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

      if (!connected) throw Exception('Timeout: dispositivo non connesso');

      // Scopri servizi
      List<BluetoothService> services = await device.discoverServices();

      // Abilita notifiche su caratteristica chiave per mantenere connessione
      await _enableNotification(device, services);

      _setupConnectionMonitoring(device);

      return true;
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<void> _enableNotification(
      BluetoothDevice device, List<BluetoothService> services) async {
    // Modifica l'UUID con la characteristic da notificare per il tuo device
    final Guid notifyCharacteristicUuid =
        Guid("00002a37-0000-1000-8000-00805f9b34fb"); // esempio battito cardiaco

    BluetoothCharacteristic? notifyCharacteristic;

    for (var service in services) {
      try {
        notifyCharacteristic = service.characteristics.firstWhere(
          (c) => c.uuid == notifyCharacteristicUuid,
        );
        break;
      } catch (_) {
        continue;
      }
    }

    if (notifyCharacteristic != null) {
      if (!notifyCharacteristic.isNotifying) {
        await notifyCharacteristic.setNotifyValue(true);
      }

      // cancella eventuale precedente subscription
      await _characteristicSubscriptions[device.remoteId.str]?.cancel();

      _characteristicSubscriptions[device.remoteId.str] =
          notifyCharacteristic.value.listen((data) {
        print('Dati notificati ricevuti: $data');
        // Qui puoi inserire la logica per inviare dati al server o altro
      });
    } else {
      print('Caratteristica notifiche non trovata');
    }
  }

  Future<void> _cleanupExistingConnection(BluetoothDevice device) async {
    try {
      await _connectionSubscriptions[device.remoteId.str]?.cancel();
      _connectionSubscriptions.remove(device.remoteId.str);

      await _characteristicSubscriptions[device.remoteId.str]?.cancel();
      _characteristicSubscriptions.remove(device.remoteId.str);

      if (_connectedDevices.containsKey(device.remoteId.str)) {
        try {
          await device.disconnect().timeout(const Duration(seconds: 2));
        } catch (_) {}
        _connectedDevices.remove(device.remoteId.str);
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  void _setupConnectionMonitoring(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str] = device.connectionState.listen(
      (state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_maintainConnectionInBackground) {
            _attemptReconnection(device);
          } else {
            _cleanupDevice(device);
          }
        }
      },
      onError: (_) {
        if (_maintainConnectionInBackground) {
          _attemptReconnection(device);
        } else {
          _cleanupDevice(device);
        }
      },
    );
    _connectedDevices[device.remoteId.str] = device;
  }

  Future<void> _attemptReconnection(BluetoothDevice device) async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      await device.discoverServices();
    } catch (_) {
      _cleanupDevice(device);
    }
  }

  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await _characteristicSubscriptions[device.remoteId.str]?.cancel();
      _characteristicSubscriptions.remove(device.remoteId.str);
      await device.disconnect();
    } catch (_) {}
    _cleanupDevice(device);
  }

  void _cleanupDevice(BluetoothDevice device) {
    _connectionSubscriptions[device.remoteId.str]?.cancel();
    _connectionSubscriptions.remove(device.remoteId.str);
    _characteristicSubscriptions[device.remoteId.str]?.cancel();
    _characteristicSubscriptions.remove(device.remoteId.str);
    _connectedDevices.remove(device.remoteId.str);
  }

  bool isDeviceConnected(BluetoothDevice device) {
    return _connectedDevices.containsKey(device.remoteId.str);
  }

  void setMaintainConnectionInBackground(bool maintain) {
    _maintainConnectionInBackground = maintain;
  }

  void dispose() {
    for (var device in _connectedDevices.values) {
      disconnectFromDevice(device);
    }
    for (var sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    for (var sub in _characteristicSubscriptions.values) {
      sub.cancel();
    }
    _connectionSubscriptions.clear();
    _connectedDevices.clear();
    _characteristicSubscriptions.clear();
  }
}
