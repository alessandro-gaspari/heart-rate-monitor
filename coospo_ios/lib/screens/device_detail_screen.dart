import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum CoospoDeviceType { none, heartRateBand, armband, unknown }

CoospoDeviceType getCoospoDeviceType(String deviceName) {
  deviceName = deviceName.toLowerCase();
  if (!deviceName.contains('coospo')) {
    return CoospoDeviceType.none;
  } else if (deviceName.contains('heart rate band')) {
    return CoospoDeviceType.heartRateBand;
  } else if (deviceName.contains('armband')) {
    return CoospoDeviceType.armband;
  }
  return CoospoDeviceType.unknown;
}

Color getCoospoColor(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand: return Colors.red;
    case CoospoDeviceType.armband: return Colors.orange;
    case CoospoDeviceType.unknown: return Colors.purple;
    default: return const Color(0xFF667eea);
  }
}

class DeviceDetailScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  bool isConnected = false;
  bool isStreaming = false;
  int currentHeartRate = 0;
  
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  WebSocketChannel? _channel;
  
  late AnimationController _heartbeatController;
  
  late CoospoDeviceType deviceType;

  final String serverUrl = 'wss://heart-rate-monitor-hu47.onrender.com';

  @override
  void initState() {
    super.initState();
    deviceType = getCoospoDeviceType(widget.device.platformName);

    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _connectToDevice();
    _listenToDeviceState();
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _stopStreaming();
    _deviceStateSubscription?.cancel();
    super.dispose();
  }

  void _triggerHeartbeat() {
    _heartbeatController.forward().then((_) {
      _heartbeatController.reverse();
    });
  }

  void _listenToDeviceState() {
    _deviceStateSubscription = widget.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          isConnected = false;
          isStreaming = false;
          currentHeartRate = 0;
        });
        _showMessage('Dispositivo disconnesso', true);
      } else if (state == BluetoothConnectionState.connected) {
        setState(() {
          isConnected = true;
        });
      }
    });
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        isConnected = true;
      });
      _showMessage('Connesso a ${widget.device.platformName}', false);
    } catch (e) {
      _showMessage('Errore connessione: $e', true);
      setState(() {
        isConnected = false;
      });
    }
  }

  Future<void> _disconnect() async {
    print('🔴 DISCONNESSIONE');
    
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    try {
      await widget.device.disconnect();
    } catch (e) {
      print('Errore disconnect: $e');
    }
    
    setState(() {
      isConnected = false;
      isStreaming = false;
      currentHeartRate = 0;
    });
    
    Navigator.pop(context);
  }

  Future<void> _startStreaming() async {
    if (!isConnected) {
      _showMessage('Connetti prima il dispositivo', true);
      return;
    }

    print('=== INIZIO STREAMING ===');
    setState(() => isStreaming = true);

    try {
      print('🔌 Connessione WebSocket: $serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      _channel?.stream.listen(
        (message) {
          print('📨 Risposta server: $message');
        },
        onError: (error) {
          print('❌ Errore WebSocket: $error');
        },
      );

      print('Ricerca servizi BLE...');
      List<BluetoothService> services = await widget.device.discoverServices();
      print('Trovati ${services.length} servizi');

      final Guid characteristicUuid = Guid("00002a37-0000-1000-8000-00805f9b34fb");
      
      BluetoothCharacteristic? characteristic;
      for (var service in services) {
        try {
          characteristic = service.characteristics.firstWhere(
            (c) => c.uuid == characteristicUuid,
          );
          print('✅ Caratteristica trovata');
          break;
        } catch (_) {}
      }

      if (characteristic == null) {
        print('❌ Caratteristica non trovata!');
        _showMessage('Caratteristica non trovata', true);
        await _stopStreaming();
        return;
      }

      print('Abilitazione notifiche...');
      await characteristic.setNotifyValue(true);
      print('✅ Notifiche abilitate');

      _characteristicSubscription = characteristic.value.listen((data) {
        if (data.isEmpty) return;
        
        int hr = _decodeData(data);
        
        if (hr > 0) {
          setState(() {
            currentHeartRate = hr;
          });
          _triggerHeartbeat();
          print('❤️  Heart Rate: $hr bpm');
        }
        
        final encoded = base64.encode(data);
        
        try {
          _channel?.sink.add(encoded);
          print('✅ Dati inviati al server');
        } catch (e) {
          print('❌ Errore invio: $e');
        }
      });

      print('✅ Streaming attivo');
      _showMessage('Streaming avviato', false);
      
    } catch (e) {
      print('❌ ERRORE: $e');
      _showMessage('Errore: $e', true);
      await _stopStreaming();
    }
  }

  Future<void> _stopStreaming() async {
    print('=== FINE STREAMING ===');
    setState(() => isStreaming = false);
    
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    print('✅ Stream terminato');
  }

  int _decodeData(List<int> data) {
    if (deviceType == CoospoDeviceType.heartRateBand) {
      if (data.isEmpty) return 0;
      int flags = data[0];
      bool is16Bit = (flags & 0x01) != 0;
      if (is16Bit && data.length >= 3) {
        return (data[2] << 8) | data[1];
      } else if (data.length >= 2) {
        return data[1];
      }
      return 0;
    } else if (deviceType == CoospoDeviceType.armband) {
      if (data.length >= 3) {
        return data[2];
      }
      return 0;
    }

    if (data.isEmpty) return 0;
    int flags = data[0];
    bool is16Bit = (flags & 0x01) != 0;
    if (is16Bit && data.length >= 3) {
      return (data[2] << 8) | data[1];
    } else if (data.length >= 2) {
      return data[1];
    }
    return 0;
  }

  void _showMessage(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5F2EEA),
        title: Text(
          deviceType != CoospoDeviceType.none
              ? 'COOSPO ${deviceType.name.toUpperCase()}'
              : widget.device.platformName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _disconnect,
            color: Colors.white,
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                CurvedAnimation(
                  parent: _heartbeatController,
                  curve: Curves.easeOut,
                ),
              ),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      getCoospoColor(deviceType).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    '❤️',
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              currentHeartRate > 0 ? '$currentHeartRate' : '--',
              style: TextStyle(
                fontSize: 90,
                fontWeight: FontWeight.bold,
                color: getCoospoColor(deviceType),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'BPM',
              style: TextStyle(
                fontSize: 24,
                color: getCoospoColor(deviceType).withOpacity(0.7),
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 90),
            if (isConnected && !isStreaming)
              ElevatedButton.icon(
                onPressed: _startStreaming,
                icon: const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  'START STREAM',
                  style: TextStyle(fontSize: 18, color: getCoospoColor(deviceType)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 8,
                  foregroundColor: getCoospoColor(deviceType),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            if (isStreaming)
              ElevatedButton.icon(
                onPressed: _stopStreaming,
                icon: const Icon(Icons.stop, size: 28),
                label: Text(
                  'STOP STREAM',
                  style: TextStyle(fontSize: 18, color: getCoospoColor(deviceType)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getCoospoColor(deviceType),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
