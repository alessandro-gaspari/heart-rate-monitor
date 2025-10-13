import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/bluetooth_connection_service.dart';

class DeviceDetailScreen extends StatefulWidget {
  final BluetoothDevice device;
  final bool isCoospo;

  const DeviceDetailScreen({
    Key? key,
    required this.device,
    this.isCoospo = false,
  }) : super(key: key);

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  final BluetoothConnectionService _bluetoothService = BluetoothConnectionService();
  
  bool isConnecting = false;
  bool isConnected = false;
  bool isStreaming = false;
  String connectionStatus = 'Disconnesso';
  
  int currentHeartRate = 0;
  List<double> rrIntervals = [];

  WebSocketChannel? _channel;
  StreamSubscription? _characteristicSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  
  // Animazione del cuore
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  final String serverUrl = 'ws://172.20.10.3:8765';

  @override
  void initState() {
    super.initState();
    _setupHeartbeatAnimation();
    _setupConnectionListener();
    _initConnection();
  }

  void _setupHeartbeatAnimation() {
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );
  }

  void _triggerHeartbeat() {
    if (_heartbeatController.isAnimating) return;
    _heartbeatController.forward().then((_) {
      _heartbeatController.reverse();
    });
  }

  void _setupConnectionListener() {
    _deviceStateSubscription = widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          isConnected = state == BluetoothConnectionState.connected;
          switch (state) {
            case BluetoothConnectionState.connected:
              connectionStatus = 'Connesso';
              isConnecting = false;
              break;
            case BluetoothConnectionState.connecting:
              connectionStatus = 'Connessione in corso...';
              break;
            case BluetoothConnectionState.disconnecting:
              connectionStatus = 'Disconnessione...';
              break;
            case BluetoothConnectionState.disconnected:
              connectionStatus = 'Disconnesso';
              isConnecting = false;
              isStreaming = false;
              currentHeartRate = 0;
              break;
          }
        });
      }
    });
  }

  void _initConnection() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connessione in corso...';
    });

    bool success = await _bluetoothService.connectToDevice(widget.device);

    if (success) {
      setState(() {
        isConnected = true;
        isConnecting = false;
        connectionStatus = 'Connesso';
      });
      _showMessage('Dispositivo connesso con successo', false);
    } else {
      setState(() {
        isConnected = false;
        isConnecting = false;
        connectionStatus = 'Errore connessione';
      });
      _showMessage('Errore durante la connessione al dispositivo', true);
    }
  }

  Future<void> _disconnect() async {
    print('🔴 DISCONNESSIONE FORZATA');
    
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    _bluetoothService.setMaintainConnectionInBackground(false);

    try {
      await _bluetoothService.disconnectFromDevice(widget.device);
    } catch (e) {
      print('Errore servizio disconnect: $e');
    }

    try {
      final currentState = await widget.device.connectionState.first;
      if (currentState == BluetoothConnectionState.connected) {
        await widget.device.disconnect();
        await widget.device.connectionState
            .firstWhere((state) => state == BluetoothConnectionState.disconnected)
            .timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      print('Errore device disconnect: $e');
    }

    if (mounted) {
      setState(() {
        isConnected = false;
        isConnecting = false;
        isStreaming = false;
        connectionStatus = 'Disconnesso';
        currentHeartRate = 0;
        rrIntervals.clear();
      });
    }

    _showMessage('Dispositivo disconnesso', true);
  }

  void _toggleStreaming() {
    if (isStreaming) {
      _stopStreaming();
    } else {
      _startStreaming();
    }
  }

  int _decodeHeartRate(List<int> data) {
    if (data.length < 2) return 0;
    
    int flags = data[0];
    int hrFormat = flags & 0x01;
    
    if (hrFormat == 0) {
      return data[1];
    } else {
      if (data.length >= 3) {
        return data[1] | (data[2] << 8);
      }
    }
    return 0;
  }

  Future<void> _startStreaming() async {
    if (!isConnected) {
      _showMessage('Connetti prima il dispositivo', true);
      return;
    }

    print('=== INIZIO STREAMING ===');
    setState(() => isStreaming = true);

    try {
      // 1. CONNESSIONE WEBSOCKET
      print('Connessione al server WebSocket: $serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      
      _channel?.stream.listen(
        (message) {
          print('✅ Risposta dal server: $message');
        },
        onError: (error) {
          print('❌ ERRORE WebSocket: $error');
          _showMessage('Errore connessione server: $error', true);
        },
        onDone: () {
          print('⚠️ WebSocket chiuso dal server');
        },
      );
      
      print('✅ WebSocket connesso');

      // 2. SCOPRI SERVIZI BLE
      print('Ricerca servizi BLE...');
      List<BluetoothService> services = await widget.device.discoverServices();
      print('Trovati ${services.length} servizi');

      // 3. TROVA CARATTERISTICA HEART RATE
      final Guid characteristicUuid = Guid("00002a37-0000-1000-8000-00805f9b34fb");
      print('Ricerca characteristic con UUID: $characteristicUuid');
      
      BluetoothCharacteristic? characteristic;
      for (var service in services) {
        try {
          characteristic = service.characteristics.firstWhere(
            (c) => c.uuid == characteristicUuid,
          );
          print('✅ Caratteristica trovata nel service: ${service.uuid}');
          break;
        } catch (_) {}
      }

      if (characteristic == null) {
        print('❌ ERRORE: Caratteristica non trovata!');
        _showMessage('Caratteristica per streaming non trovata', true);
        await _stopStreaming();
        return;
      }

      // 4. ABILITA NOTIFICHE
      print('Abilitazione notifiche sulla caratteristica...');
      await characteristic.setNotifyValue(true);
      print('✅ Notifiche abilitate');

      // 5. LISTENER DATI BLE → INVIO AL SERVER
      _characteristicSubscription = characteristic.value.listen((data) {
        print('<<< Dati ricevuti da BLE: $data');
        
        // Filtra i dati vuoti
        if (data.isEmpty) {
          print('⚠️ Dati vuoti ricevuti, in attesa di battito cardiaco...');
          return;
        }
        
        // Decodifica Heart Rate
        int hr = _decodeHeartRate(data);
        
        if (hr > 0) {
          setState(() {
            currentHeartRate = hr;
          });
          _triggerHeartbeat();
          print('❤️  Heart Rate decodificato: $hr bpm');
        }
        
        // INVIA AL SERVER WEBSOCKET (BASE64)
        final encoded = base64.encode(data);
        print('>>> Invio al WebSocket (base64): $encoded (${data.length} bytes)');
        
        try {
          _channel?.sink.add(encoded);
          print('✅ Dati inviati al server con successo');
        } catch (e) {
          print('❌ Errore invio dati al WebSocket: $e');
        }
      });

      print('✅ Listener BLE attivo');
      _showMessage('Streaming avviato - Indossa il dispositivo', false);
      print('=== STREAMING ATTIVO ===');
      
    } catch (e) {
      print('❌ ERRORE durante avvio streaming: $e');
      _showMessage('Errore streaming: $e', true);
      await _stopStreaming();
    }
  }


  Future<void> _stopStreaming() async {
    setState(() => isStreaming = false);
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    await _channel?.sink.close();
    _channel = null;
    setState(() => currentHeartRate = 0);
    _showMessage('Streaming interrotto', true);
  }

  void _showMessage(String message, bool isError) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: GoogleFonts.montserrat(fontSize: 15)),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _deviceStateSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bluetoothBlue = const Color(0xFF0082FC);
    final Color disconnectRed = const Color(0xFFE53935);
    final Color streamGreen = const Color(0xFF43A047);
    final Color darkBg = const Color(0xFF121212);
    final Color cardBg = const Color(0xFF1E1E1E);
    final Color neonPink = const Color(0xFFFF006E);
    final Color neonBlue = const Color(0xFF00F5FF);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.device.name.isEmpty ? 'Dispositivo BLE' : widget.device.name,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: cardBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () async {
            if (isConnected) await _disconnect();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CUORE ANIMATO CON BPM
              if (isStreaming && currentHeartRate > 0)
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        neonPink.withOpacity(0.3),
                        darkBg,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: neonPink.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _heartbeatAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _heartbeatAnimation.value,
                        child: Column(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: neonPink,
                              size: 120,
                              shadows: [
                                Shadow(
                                  color: neonPink.withOpacity(0.8),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '$currentHeartRate',
                              style: GoogleFonts.orbitron(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: neonBlue,
                                shadows: [
                                  Shadow(
                                    color: neonBlue.withOpacity(0.8),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'BPM',
                              style: GoogleFonts.orbitron(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: neonBlue.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (!isStreaming || currentHeartRate == 0)
                Container(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        color: Colors.grey[600],
                        size: 120,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '--',
                        style: GoogleFonts.orbitron(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        'BPM',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),

              // Card stato connessione
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isConnected
                        ? [Colors.green[400]!, Colors.green[600]!]
                        : [Colors.red[700]!, Colors.red[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: isConnected
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      connectionStatus,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Pulsanti
              SizedBox(
                width: 260,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isConnecting
                      ? null
                      : (isConnected ? _disconnect : _initConnection),
                  icon: Icon(isConnected ? Icons.bluetooth_disabled : Icons.bluetooth, size: 28),
                  label: Text(
                    isConnected ? 'Disconnetti' : 'Connetti',
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? disconnectRed : bluetoothBlue,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: 260,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: (isConnected && !isConnecting) ? _toggleStreaming : null,
                  icon: Icon(
                    isStreaming ? Icons.stop_circle : Icons.play_circle_filled,
                    size: 28,
                  ),
                  label: Text(
                    isStreaming ? 'Fine Stream' : 'Inizio Stream',
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStreaming ? disconnectRed : streamGreen,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
