import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum CoospoDeviceType { none, heartRateBand, armband, unknown }

CoospoDeviceType getCoospoDeviceType(String deviceName) {
  deviceName = deviceName.toLowerCase();
  if (!deviceName.contains('coospo')) return CoospoDeviceType.none;
  if (deviceName.contains('heart rate') || deviceName.contains('h6') || deviceName.contains('h7')) {
    return CoospoDeviceType.heartRateBand;
  }
  if (deviceName.contains('armband') || deviceName.contains('pod')) {
    return CoospoDeviceType.armband;
  }
  return CoospoDeviceType.unknown;
}

Color getCoospoColor(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand:
      return const Color(0xFFFF4444);
    case CoospoDeviceType.armband:
      return const Color(0xFFFF8C00);
    case CoospoDeviceType.unknown:
      return const Color(0xFF9B59B6);
    default:
      return const Color(0xFF3498DB);
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
  int signalStrength = -50;
  
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  Timer? _rssiTimer;
  IO.Socket? _socket;
  
  late AnimationController _heartbeatController;
  late CoospoDeviceType deviceType;
  late Color deviceColor;
  
  final String serverUrl = 'https://heart-rate-monitor-hu47.onrender.com';

  @override
  void initState() {
    super.initState();
    deviceType = getCoospoDeviceType(widget.device.platformName);
    deviceColor = getCoospoColor(deviceType);

    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _listenToDeviceState();
  }

  @override
  void dispose() {
    _rssiTimer?.cancel();
    _heartbeatController.dispose();
    _stopBleReading();
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
        if (mounted) {
          setState(() {
            isConnected = false;
            isStreaming = false;
            currentHeartRate = 0;
          });
        }
        _showMessage('Dispositivo disconnesso', true);
      } else if (state == BluetoothConnectionState.connected) {
        if (mounted) {
          setState(() {
            isConnected = true;
          });
        }
        _startRssiMonitoring();
      }
    });
  }

  void _startRssiMonitoring() {
    _rssiTimer?.cancel();
    
    _rssiTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !isConnected) {
        timer.cancel();
        return;
      }
      
      widget.device.readRssi().then((rssi) {
        if (mounted) {
          setState(() {
            signalStrength = rssi;
          });
        }
      }).catchError((e) {
        print('Errore RSSI: $e');
      });
    });
  }

  Color _getSignalColor() {
    if (signalStrength > -60) return Colors.green;
    if (signalStrength > -75) return Colors.orange;
    return Colors.red;
  }

  IconData _getSignalIcon() {
    if (signalStrength > -60) return Icons.signal_cellular_alt;
    if (signalStrength > -75) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        isConnected = true;
      });
      _showMessage('Connesso', false);
      
      await _startBleReading();
    } catch (e) {
      _showMessage('Errore connessione: $e', true);
      setState(() {
        isConnected = false;
      });
    }
  }

  Future<void> _disconnect() async {
    print('🔴 DISCONNESSIONE FORZATA IMMEDIATA');
    
    if (isStreaming) {
      await _stopStreaming();
    }
    
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    _rssiTimer?.cancel();
    _rssiTimer = null;
    
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    
    setState(() {
      isConnected = false;
      isStreaming = false;
      currentHeartRate = 0;
    });
    
    try {
      print('Disconnessione Bluetooth...');
      await widget.device.disconnect(timeout: 5).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Timeout disconnessione - forzando chiusura');
        },
      );
      print('✅ Bluetooth disconnesso');
    } catch (e) {
      print('❌ Errore disconnect (ignorato): $e');
    }
    
    _showMessage('Disconnesso', false);
    print('✅ Disconnessione completata');
  }

  Future<void> _startBleReading() async {
    print('=== INIZIO LETTURA BLE ===');

    try {
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
          
          if (isStreaming && _socket != null && _socket!.connected) {
            _sendToServer(data);
          }
        }
      });

      print('✅ Lettura BLE attiva');
      
    } catch (e) {
      print('❌ ERRORE BLE: $e');
      _showMessage('Errore lettura BLE: $e', true);
    }
  }

  Future<void> _stopBleReading() async {
    print('=== FINE LETTURA BLE ===');
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
  }

  Future<void> _startStreaming() async {
    if (!isConnected) {
      _showMessage('Connetti prima il dispositivo', true);
      return;
    }

    print('=== INIZIO STREAMING AL SERVER ===');
    setState(() => isStreaming = true);

    try {
      print('🔌 Connessione Socket.IO: $serverUrl');
      
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      
      _socket?.connect();
      
      _socket?.onConnect((_) {
        print('✅ Socket.IO connesso');
        _showMessage('Streaming avviato', false);
      });
      
      _socket?.onDisconnect((_) {
        print('⚠️ Socket.IO disconnesso');
      });
      
      _socket?.onError((error) {
        print('❌ Errore Socket.IO: $error');
      });
      
    } catch (e) {
      print('❌ ERRORE STREAMING: $e');
      _showMessage('Errore streaming: $e', true);
      await _stopStreaming();
    }
  }

  void _sendToServer(List<int> data) {
    if (_socket == null || !_socket!.connected) {
      print('❌ Socket non connesso');
      return;
    }
    
    final encoded = base64.encode(data);
    final deviceTypeStr = deviceType.toString().split('.').last;
    
    final message = {
      'device_type': deviceTypeStr,
      'device_id': widget.device.platformName,
      'data': encoded
    };
    
    try {
      _socket?.emit('heart_rate_data', message);
      print('✅ Dati inviati al server');
    } catch (e) {
      print('❌ Errore invio: $e');
    }
  }

  Future<void> _stopStreaming() async {
    print('=== FINE STREAMING ===');
    setState(() => isStreaming = false);
    
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    
    print('✅ Streaming terminato');
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
      if (data.length >= 2) {
        return data[1];
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
    final signalColor = _getSignalColor();
    final signalIcon = _getSignalIcon();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.device.platformName.isEmpty ? 'Dispositivo' : widget.device.platformName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: signalColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: signalColor, width: 2),
              ),
              child: Row(
                children: [
                  Icon(signalIcon, color: signalColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '${signalStrength} dBm',
                    style: TextStyle(
                      color: signalColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.3).animate(
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
                    boxShadow: [
                      BoxShadow(
                        color: deviceColor.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '❤️',
                      style: TextStyle(
                        fontSize: 100,
                        shadows: [
                          Shadow(
                            color: deviceColor.withOpacity(0.6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 50),
              
              Text(
                currentHeartRate > 0 ? '$currentHeartRate' : '--',
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.w900,
                  color: deviceColor,
                  letterSpacing: -2,
                  shadows: [
                    Shadow(
                      color: deviceColor.withOpacity(0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
              
              Text(
                'BPM',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: deviceColor.withOpacity(0.7),
                  letterSpacing: 8,
                ),
              ),
              
              const SizedBox(height: 80),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    if (!isConnected)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _connectToDevice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deviceColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 12,
                            shadowColor: deviceColor.withOpacity(0.6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.bluetooth_connected, size: 32),
                              SizedBox(width: 12),
                              Text(
                                'CONNETTI',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (isConnected) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isStreaming ? _stopStreaming : _startStreaming,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isStreaming ? Colors.red : deviceColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 12,
                            shadowColor: (isStreaming ? Colors.red : deviceColor).withOpacity(0.6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isStreaming ? Icons.stop_circle : Icons.cloud_upload,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isStreaming ? 'STOP STREAM' : 'START STREAM',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _disconnect,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.bluetooth_disabled, size: 28),
                              SizedBox(width: 12),
                              Text(
                                'DISCONNETTI',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
