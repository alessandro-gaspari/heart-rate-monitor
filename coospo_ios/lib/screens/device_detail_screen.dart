import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'activity_screen.dart';
import 'activity_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


enum CoospoDeviceType { none, heartRateBand, armband, unknown }

CoospoDeviceType getCoospoDeviceType(String deviceName) {
  deviceName = deviceName.toLowerCase();
  if (!deviceName.contains('coospo')) return CoospoDeviceType.none;
  if (deviceName.contains('heart rate') || deviceName.contains('h6') || 
      deviceName.contains('h7') || deviceName.contains('808')) {
    return CoospoDeviceType.heartRateBand;
  }
  if (deviceName.contains('armband') || deviceName.contains('pod')) {
    return CoospoDeviceType.armband;
  }
  return CoospoDeviceType.unknown;
}

Color getCoospoColor(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand: return const Color(0xFFFF4444);
    case CoospoDeviceType.armband: return const Color(0xFFFF8C00);
    case CoospoDeviceType.unknown: return const Color(0xFF9B59B6);
    default: return const Color(0xFF3498DB);
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
  
  // BLE State
  bool isConnected = false;
  bool isStreaming = false;
  int currentHeartRate = 0;
  int signalStrength = -50;
  
  // UI State
  bool isMapExpanded = false;
  
  // Activity Tracking
  bool isActivityRunning = false;
  int? currentActivityId;
  Timer? waypointTimer;
  double totalDistance = 0.0;
  int waypointCount = 0;
  DateTime? activityStartTime;
  
  // Streams for activity screen
  final StreamController<int> _heartRateStreamController = StreamController<int>.broadcast();
  final StreamController<LatLng> _positionStreamController = StreamController<LatLng>.broadcast();
  
  // Subscriptions & Controllers
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  Timer? _rssiTimer;
  IO.Socket? _socket;
  late AnimationController _heartbeatController;
  late CoospoDeviceType deviceType;
  late Color deviceColor;
  
  // GPS
  AppleMapController? mapController;
  LatLng? currentPosition;
  LatLng? lastWaypointPosition;
  StreamSubscription<Position>? positionStream;
  
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
    _startTracking();
  }

  @override
  void dispose() {
    _heartRateStreamController.close();
    _positionStreamController.close();
    _rssiTimer?.cancel();
    _heartbeatController.dispose();
    _stopBleReading();
    _stopStreaming();
    _stopActivity();
    _deviceStateSubscription?.cancel();
    positionStream?.cancel();
    waypointTimer?.cancel();
    super.dispose();
  }

  // ========== GPS TRACKING ==========
  
  void _startTracking() async {
    print("🌍 Inizio tracking GPS...");
    if (mounted) setState(() => currentPosition = const LatLng(45.4642, 9.19));
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2), onTimeout: () => false,
      );
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best
      ).timeout(const Duration(seconds: 5));
      
      if (mounted) {
        setState(() => currentPosition = LatLng(pos.latitude, pos.longitude));
      }

      positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: Duration(milliseconds: 500),
        )).listen((Position p) {
        if (mounted) {
          final pos = LatLng(p.latitude, p.longitude);
          setState(() => currentPosition = pos);
          _positionStreamController.add(pos);
        }
      });
      
    } catch (e) {
      print("❌ Errore GPS: $e");
    }
  }

  Future<void> _refreshGPS() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best
      ).timeout(const Duration(seconds: 5));
      
      final newPosition = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => currentPosition = newPosition);
      
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newPosition, zoom: 17.0),
          ),
        );
      }
      _showMessage('Posizione aggiornata');
    } catch (e) {
      _showMessage('Errore aggiornamento GPS');
    }
  }

  // ========== ACTIVITY TRACKING ==========
  
  Future<void> _startActivity() async {
    print("🚀 _startActivity() chiamato");
    
    if (!isConnected) {
      print("❌ Dispositivo non connesso");
      _showMessage('Connetti prima il dispositivo BLE');
      return;
    }
    
    print("✅ Dispositivo connesso, mostro countdown...");
    await _showCountdown();
    print("✅ Countdown completato");
    
    try {
      print("📡 Invio richiesta al server: $serverUrl/api/activity/start");
      
      final response = await http.post(
        Uri.parse('$serverUrl/api/activity/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'device_id': widget.device.platformName}),
      ).timeout(const Duration(seconds: 10));
      
      print("📥 Risposta server: ${response.statusCode}");
      print("📥 Body: ${response.body}");
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        currentActivityId = data['activity_id'];
        
        print("✅ Activity ID: $currentActivityId");
        
        setState(() {
          isActivityRunning = true;
          activityStartTime = DateTime.now();
          totalDistance = 0.0;
          waypointCount = 0;
          lastWaypointPosition = currentPosition;
        });
        
        print("✅ State aggiornato: isActivityRunning = $isActivityRunning");
        
        // Timer waypoints
        waypointTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (isActivityRunning && currentPosition != null) {
            _sendWaypoint();
          }
        });
        
        print("🗺️ Navigating to ActivityScreen...");
        
        // NAVIGAZIONE
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityScreen(
              activityId: currentActivityId!,
              onStopActivity: _stopActivity,
              heartRateStream: _heartRateStreamController.stream,
              positionStream: _positionStreamController.stream,
            ),
          ),
        );
        
        print("✅ Ritorno da ActivityScreen");
        
      } else {
        print("❌ Errore server: ${response.statusCode}");
        _showMessage('Errore server: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print("❌ ERRORE CRITICO start activity: $e");
      print("Stack trace: $stackTrace");
      _showMessage('Errore avvio attività: $e');
    }
  }


  Future<void> _showCountdown() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CountdownDialog(),
    );
  }

  Future<void> _sendWaypoint() async {
    if (currentActivityId == null || currentPosition == null) return;
    
    try {
      if (lastWaypointPosition != null) {
        final distance = Geolocator.distanceBetween(
          lastWaypointPosition!.latitude,
          lastWaypointPosition!.longitude,
          currentPosition!.latitude,
          currentPosition!.longitude,
        );
        setState(() {
          totalDistance += distance / 1000;
          waypointCount++;
        });
      }
      
      await http.post(
        Uri.parse('$serverUrl/api/activity/waypoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'activity_id': currentActivityId,
          'latitude': currentPosition!.latitude,
          'longitude': currentPosition!.longitude,
          'heart_rate': currentHeartRate,
        }),
      );
      
      lastWaypointPosition = currentPosition;
      
    } catch (e) {
      print("❌ Errore waypoint: $e");
    }
  }

  Future<void> _stopActivity([int? activityId]) async {
    final id = activityId ?? currentActivityId;
    if (id == null) return;
    
    try {
      print("🛑 Arresto attività...");
      waypointTimer?.cancel();
      
      final response = await http.post(
        Uri.parse('$serverUrl/api/activity/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'activity_id': id}),
      );
      
      if (response.statusCode == 200) {
        // final stats = json.decode(response.body);
        setState(() => isActivityRunning = false);
        
        print("✅ Attività terminata, navigando alla summary...");
        
        // NAVIGA ALLA SUMMARY SCREEN
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActivitySummaryScreen(activityId: id),
            ),
          );
        }
      } else {
        print("❌ Errore server: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Errore stop activity: $e");
    }
  }


  /*
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
  */

  // ========== BLE CONNECTION & STREAMING ==========
  
  void _triggerHeartbeat() {
    _heartbeatController.forward().then((_) => _heartbeatController.reverse());
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
      } else if (state == BluetoothConnectionState.connected) {
        if (mounted) setState(() => isConnected = true);
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
        if (mounted) setState(() => signalStrength = rssi);
      }).catchError((e) {});
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
      setState(() => isConnected = true);
      
      // SALVA DEVICE ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_id', widget.device.platformName);
      print("✅ Device ID salvato: ${widget.device.platformName}");
      
      await _startBleReading();
    } catch (e) {
      setState(() => isConnected = false);
    }
  }


  Future<void> _disconnect() async {
    print('🔴 DISCONNESSIONE');
    if (isActivityRunning && currentActivityId != null) {
      await _stopActivity(currentActivityId!);
    }
    if (isStreaming) await _stopStreaming();
    
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _rssiTimer?.cancel();
    
    setState(() {
      isConnected = false;
      isStreaming = false;
      currentHeartRate = 0;
    });
    
    try {
      await widget.device.disconnect();
    } catch (e) {
      print('❌ Errore disconnect: $e');
    }
  }

  Future<void> _startBleReading() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      final Guid characteristicUuid = Guid("00002a37-0000-1000-8000-00805f9b34fb");
      
      BluetoothCharacteristic? characteristic;
      for (var service in services) {
        try {
          characteristic = service.characteristics.firstWhere((c) => c.uuid == characteristicUuid);
          break;
        } catch (_) {}
      }

      if (characteristic == null) return;
      await characteristic.setNotifyValue(true);

      _characteristicSubscription = characteristic.value.listen((data) {
        if (data.isEmpty) return;
        int hr = _decodeData(data);
        
        if (hr > 0) {
          setState(() => currentHeartRate = hr);
          _triggerHeartbeat();
          _heartRateStreamController.add(hr);
          
          if (isStreaming && _socket != null && _socket!.connected) {
            _sendToServer(data);
          }
        }
      });
    } catch (e) {
      print('❌ ERRORE BLE: $e');
    }
  }

  Future<void> _stopBleReading() async {
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
  }

  Future<void> _startStreaming() async {
    if (!isConnected) return;
    setState(() => isStreaming = true);

    try {
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      _socket?.connect();
      _socket?.onConnect((_) => print('✅ Socket.IO connesso'));
      _socket?.onDisconnect((_) => print('⚠️ Socket disconnesso'));
      _socket?.onError((error) => print('❌ Errore Socket.IO: $error'));
    } catch (e) {
      print('❌ ERRORE STREAMING: $e');
      await _stopStreaming();
    }
  }

  void _sendToServer(List<int> data) {
    if (_socket == null || !_socket!.connected) return;
    
    final encoded = base64.encode(data);
    final deviceTypeStr = deviceType.toString().split('.').last;
    
    final message = {
      'device_type': deviceTypeStr,
      'device_id': widget.device.platformName,
      'data': encoded,
      'latitude': currentPosition?.latitude,
      'longitude': currentPosition?.longitude,
    };
    
    _socket?.emit('heart_rate_data', message);
  }

  Future<void> _stopStreaming() async {
    setState(() => isStreaming = false);
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  int _decodeData(List<int> data) {
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  // ========== UI BUILD ==========

  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor();
    final signalIcon = _getSignalIcon();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: Text(
          widget.device.platformName.isEmpty ? 'Dispositivo' : widget.device.platformName,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                  Icon(signalIcon, color: signalColor, size: 18),
                  const SizedBox(width: 6),
                  Text('${signalStrength} dBm',
                    style: TextStyle(color: signalColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // MAPPA
              Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    height: isMapExpanded ? MediaQuery.of(context).size.height * 0.5 : 180,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: deviceColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AppleMap(
                        onMapCreated: (controller) => mapController = controller,
                        initialCameraPosition: CameraPosition(
                          target: currentPosition ?? const LatLng(45.4642, 9.19),
                          zoom: 16.0,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        compassEnabled: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 30,
                    right: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: deviceColor,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: deviceColor.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.white),
                        iconSize: 24,
                        onPressed: _refreshGPS,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Espandi/Comprimi
              InkWell(
                onTap: () => setState(() => isMapExpanded = !isMapExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isMapExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.white54, size: 28),
                      const SizedBox(width: 8),
                      Text(isMapExpanded ? 'Comprimi' : 'Espandi',
                        style: const TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              
              // BATTITO + BOTTONI
              if (!isMapExpanded)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                              CurvedAnimation(parent: _heartbeatController, curve: Curves.easeOut)),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: deviceColor.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
                              ),
                              child: const Center(child: Text('❤️', style: TextStyle(fontSize: 60))),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(currentHeartRate > 0 ? '$currentHeartRate' : '--',
                            style: TextStyle(fontSize: 70, fontWeight: FontWeight.w900, color: deviceColor)),
                          Text('BPM', style: TextStyle(fontSize: 20, color: deviceColor.withOpacity(0.7), letterSpacing: 6)),
                          const SizedBox(height: 30),
                          
                          if (!isConnected)
                            _buildButton(label: 'CONNETTI', icon: Icons.bluetooth_connected, 
                              color: deviceColor, onPressed: _connectToDevice),
                          
                          if (isConnected) ...[
                            _buildButton(label: 'START ATTIVITÀ', icon: Icons.play_arrow,
                              color: Colors.green, onPressed: _startActivity, size: 18),
                            const SizedBox(height: 12),
                            _buildButton(label: isStreaming ? 'STOP STREAM' : 'START STREAM',
                              icon: isStreaming ? Icons.stop_circle : Icons.cloud_upload,
                              color: isStreaming ? Colors.red : deviceColor,
                              onPressed: isStreaming ? _stopStreaming : _startStreaming),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _disconnect,
                                icon: const Icon(Icons.bluetooth_disabled, size: 22),
                                label: const Text('DISCONNETTI',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
        if (isMapExpanded)
          Positioned(
            bottom: 120,
            right: 70,
            left: 70,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: deviceColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: deviceColor.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: deviceColor, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentHeartRate > 0 ? '$currentHeartRate BPM' : ' -- BPM ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis, // evita overflow
                      textAlign: TextAlign.center,     // centra il testo
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.favorite, color: deviceColor, size: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 16,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, letterSpacing: 2)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ========== COUNTDOWN DIALOG ==========

class _CountdownDialog extends StatefulWidget {
  @override
  __CountdownDialogState createState() => __CountdownDialogState();
}

class __CountdownDialogState extends State<_CountdownDialog> 
    with SingleTickerProviderStateMixin {
  int countdown = 3;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _startCountdown();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startCountdown() async {
    for (int i = 3; i > 0; i--) {
      if (mounted) {
        setState(() => countdown = i);
        _controller.forward(from: 0);
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    
    // VIA!
    if (mounted) {
      setState(() => countdown = 0);
      _controller.forward(from: 0);
    }
    
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: countdown > 0 
                      ? const Color(0xFFFC5200).withOpacity(0.7)
                      : const Color(0xFF00FF87).withOpacity(0.7),
                    blurRadius: 100,
                    spreadRadius: 30,
                  ),
                ],
              ),
              child: countdown > 0
                ? Text(
                    '$countdown',
                    style: TextStyle(
                      color: const Color(0xFFFC5200),
                      fontSize: 200,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -10,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  )
                : const Text(
                    'VIA!',
                    style: TextStyle(
                      color: Color(0xFF00FF87),
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 15,
                      fontFamily: 'SF Pro Display',
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
