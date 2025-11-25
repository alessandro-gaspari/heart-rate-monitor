// Importazioni necessarie per BLE, socket, GPS, mappe, DB locale e UI
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_screen.dart';
import 'activity_summary_screen.dart';
import '../database/local_db.dart';
import '../utils/tcp_client.dart';

// Tipi di dispositivi Coospo
enum CoospoDeviceType { none, heartRateBand, armband, unknown }

// Determina tipo dispositivo dal nome
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

// Colore associato al tipo dispositivo
Color getCoospoColor(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand:
      return const Color(0xFFFF4444);
    case CoospoDeviceType.armband:
      return const Color(0xFFFF8C00);
    case CoospoDeviceType.unknown:
      return const Color.fromARGB(255, 255, 210, 31);
    default:
      return const Color.fromARGB(255, 255, 210, 31);
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
  // Stato connessione BLE e streaming dati
  bool isConnected = false;
  bool isStreaming = false;
  int currentHeartRate = 0;
  int signalStrength = -50;

  // Stato UI espansione mappa
  bool isMapExpanded = false;

  // Stato attività (tracking)
  bool isActivityRunning = false;
  int? currentActivityId;
  Timer? waypointTimer;
  double totalDistance = 0.0;
  int waypointCount = 0;
  DateTime? activityStartTime;
  TCPDataSender? _tcpSender;

  // Storico dati locali
  final List<int> heartRateHistory = [];
  int maxHeartRate = 0;
  int minHeartRate = 999;
  final List<Map<String, dynamic>> activityWaypoints = [];

  // Stream dati per schermata attività
  final StreamController<int> _heartRateController = StreamController<int>.broadcast();
  final StreamController<LatLng> _positionController = StreamController<LatLng>.broadcast();

  // Subscription e controller BLE, GPS, socket
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  Timer? _rssiTimer;
  IO.Socket? _socket;
  late AnimationController _heartbeatController;
  late CoospoDeviceType deviceType;
  late Color deviceColor;

  // Controller mappa e posizione GPS
  AppleMapController? mapController;
  LatLng? currentPosition;
  LatLng? lastWaypointPosition;
  StreamSubscription<Position>? positionStream;

  final String serverUrl = 'https://heart-rate-monitor-hu47.onrender.com';

  @override
  void initState() {
    super.initState();
    // Determina tipo e colore dispositivo
    deviceType = getCoospoDeviceType(widget.device.platformName);
    deviceColor = getCoospoColor(deviceType);
    // Animazione battito
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _listenToDeviceState();
    _startTracking();
  }

  @override
  void dispose() {
    // Pulisce risorse e streaming
    _heartRateController.close();
    _positionController.close();
    _rssiTimer?.cancel();
    _heartbeatController.dispose();
    _stopBleReading();
    _stopStreaming();

    if (currentActivityId != null) {
      _stopActivity(currentActivityId!, 0.0);
    }

    _deviceStateSubscription?.cancel();
    positionStream?.cancel();
    waypointTimer?.cancel();
    _tcpSender?.disconnect();

    super.dispose();
  }

  // Avvia tracking GPS
  void _startTracking() async {
    print("🌍 Inizio tracking GPS...");
    if (mounted) setState(() => currentPosition = const LatLng(45.4642, 9.19));

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
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
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() => currentPosition = LatLng(pos.latitude, pos.longitude));
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(pos.latitude, pos.longitude),
                zoom: 17.0,
              ),
            ),
          );
        }
      }

      // Stream posizione aggiornata
      positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((Position p) {
        if (mounted) {
          final pos = LatLng(p.latitude, p.longitude);
          setState(() => currentPosition = pos);
          _positionController.add(pos);
        }
      });
    } catch (e) {
      print("❌ Errore GPS: $e");
    }
  }

  // Aggiorna posizione GPS manualmente
  Future<void> _refreshGPS() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
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

  // Avvia attività con countdown
  Future<void> _startActivity() async {
    await _showCountdown();

    final activityId = DateTime.now().millisecondsSinceEpoch;

    print("🏁 Inizio attività con ID: $activityId");

    setState(() {
      currentActivityId = activityId;
      isActivityRunning = true;
      activityStartTime = DateTime.now();
      totalDistance = 0.0;
      waypointCount = 0;
      heartRateHistory.clear();
      activityWaypoints.clear();
      maxHeartRate = 0;
      minHeartRate = 999;
    });

    // Salva attività in locale subito
    await LocalDatabase.saveActivity({
      'id': activityId,
      'device_id': widget.device.remoteId.toString(),
      'start_time': DateTime.now().toIso8601String(),
      'status': 'running',
      'distance': 0.0,
      'duration': 0,
      'calories': 0.0,
    });

    print("💾 Attività $activityId creata in locale");

    _startWaypointTimer();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityScreen(
            activityId: activityId,
            onStopActivity: _stopActivity,
            heartRateStream: _heartRateController.stream,
            positionStream: _positionController.stream,
          ),
        ),
      );
    }
  }

  // Mostra dialog countdown
  Future<void> _showCountdown() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CountdownDialog(),
    );
  }

  // Timer per waypoint ogni 3 secondi
  void _startWaypointTimer() {
    waypointTimer?.cancel();
    waypointTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _sendWaypoint();
    });
  }

  // Salva waypoint e calcola distanza
  Future<void> _sendWaypoint() async {
    if (currentActivityId == null || currentPosition == null) {
      print("⚠️ Waypoint saltato: activityId=$currentActivityId, position=$currentPosition");
      return;
    }

    print("📍 Salvando waypoint ${activityWaypoints.length + 1}...");

    if (lastWaypointPosition != null) {
      final distance = Geolocator.distanceBetween(
        lastWaypointPosition!.latitude,
        lastWaypointPosition!.longitude,
        currentPosition!.latitude,
        currentPosition!.longitude,
      );

      setState(() {
        totalDistance += distance;
        waypointCount++;

        if (currentHeartRate > 0) {
          heartRateHistory.add(currentHeartRate);
          if (currentHeartRate > maxHeartRate) maxHeartRate = currentHeartRate;
          if (currentHeartRate < minHeartRate) minHeartRate = currentHeartRate;
        }
      });

      print("📏 Distanza totale: ${totalDistance / 1000} km");
    }

    activityWaypoints.add({
      'latitude': currentPosition!.latitude,
      'longitude': currentPosition!.longitude,
      'heart_rate': currentHeartRate,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await LocalDatabase.saveWaypoints(currentActivityId!, activityWaypoints);
    print("💾 Waypoint ${activityWaypoints.length} salvato");

    lastWaypointPosition = currentPosition;
  }

  // Ferma attività e salva dati finali
  Future<void> _stopActivity(int activityId, [double calories = 0.0]) async {
    waypointTimer?.cancel();

    final duration = activityStartTime != null
        ? DateTime.now().difference(activityStartTime!).inSeconds
        : 0;

    print("🛑 Stop attività $activityId");
    print("⏱️ Durata: $duration secondi");
    print("📏 Distanza: ${totalDistance / 1000} km");
    print("📍 Waypoints: ${activityWaypoints.length}");
    print("🔥 Calorie: $calories");

    await LocalDatabase.saveActivity({
      'id': activityId,
      'device_id': widget.device.remoteId.toString(),
      'start_time': activityStartTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'end_time': DateTime.now().toIso8601String(),
      'status': 'completed',
      'distance': totalDistance,
      'duration': duration,
      'calories': calories,
    });

    if (activityWaypoints.isNotEmpty) {
      await LocalDatabase.saveWaypoints(activityId, activityWaypoints);
    }

    print("💾 Attività salvata completamente in locale");

    setState(() {
      isActivityRunning = false;
      currentActivityId = null;
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ActivitySummaryScreen(activityId: activityId),
        ),
      );
    }
  }

  // Animazione battito
  void _triggerHeartbeat() {
    _heartbeatController.forward().then((_) => _heartbeatController.reverse());
  }

  // Ascolta stato connessione dispositivo BLE
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

  // Timer per leggere RSSI ogni 2 secondi
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

  // Colore segnale RSSI
  Color _getSignalColor() {
    if (signalStrength > -60) return Colors.green;
    if (signalStrength > -75) return Colors.orange;
    return Colors.red;
  }

  // Icona segnale RSSI
  IconData _getSignalIcon() {
    if (signalStrength > -60) return Icons.signal_cellular_alt;
    if (signalStrength > -75) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  // Connessione al dispositivo BLE
  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() => isConnected = true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_id', widget.device.platformName);
      print("✅ Device ID salvato: ${widget.device.platformName}");

      await _startBleReading();
    } catch (e) {
      setState(() => isConnected = false);
    }
  }

  // Disconnessione dal dispositivo BLE
  Future<void> _disconnect() async {
    print('🔴 DISCONNESSIONE');

    if (isActivityRunning && currentActivityId != null) {
      await _stopActivity(currentActivityId!, 0.0);
    }

    if (isStreaming) await _stopStreaming();

    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _rssiTimer?.cancel();

    setState(() {
      isConnected = false;
      isStreaming = false;
      currentHeartRate = 0;
      isActivityRunning = false;
      currentActivityId = null;
    });

    try {
      await widget.device.disconnect();
    } catch (e) {
      print('❌ Errore disconnect: $e');
    }
  }

  // Avvia lettura dati BLE
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

      _characteristicSubscription = characteristic.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        int hr = _decodeData(data);

        if (hr > 0) {
          setState(() => currentHeartRate = hr);
          _triggerHeartbeat();
          _heartRateController.add(hr);

          if (isStreaming && _socket != null && _socket!.connected) {
            _sendToServer(data);
          }
        }
      });
    } catch (e) {
      print('❌ ERRORE BLE: $e');
    }
  }

  // Ferma lettura dati BLE
  Future<void> _stopBleReading() async {
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
  }

  // Avvia streaming dati via socket
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

      _tcpSender = TCPDataSender();
      await _tcpSender?.connect();
    } catch (e) {
      print('❌ ERRORE STREAMING: $e');
      await _stopStreaming();
    }
  }

  // Invia dati al server via socket E TCP
  void _sendToServer(List<int> data) {
    final deviceTypeStr = deviceType.toString().split('.').last;
    final hrValue = _decodeData(data);
    
    // ✅ INVIA A RENDER (Socket.IO) - come prima
    if (_socket != null && _socket!.connected) {
      final encoded = base64.encode(data);
      final message = {
        'device_type': deviceTypeStr,
        'device_id': widget.device.platformName,
        'data': encoded,
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
      };
      _socket?.emit('heart_rate_data', message);
    }
    
    // ✅ INVIA A SERVER SSH (TCP) - NUOVO
    if (_tcpSender != null && _tcpSender!.isConnected && hrValue > 0) {
      final hrData = {
        'device_type': deviceTypeStr,
        'heart_rate': hrValue,
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
      };
      
      _tcpSender!.sendData(
        widget.device.platformName,
        hrData,
      );
    }
  }

  // Ferma streaming dati
  Future<void> _stopStreaming() async {
    if (mounted) {
      setState(() => isStreaming = false);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _tcpSender?.disconnect();
    _tcpSender = null;
  }

  // Decodifica dati BLE per ottenere battito
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

  // Mostra messaggio toast
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

  // Costruzione UI
  @override
  Widget build(BuildContext context) {
    final signalColor = _getSignalColor();
    final signalIcon = _getSignalIcon();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
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
              // Mappa Apple
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
                        onMapCreated: (controller) {
                          mapController = controller;

                          if (currentPosition != null) {
                            controller.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: currentPosition!,
                                  zoom: 17.0,
                                ),
                              ),
                            );
                          }
                        },
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
                        icon: const Icon(Icons.my_location, color: Color.fromARGB(255, 0, 0, 0)),
                        iconSize: 24,
                        onPressed: _refreshGPS,
                      ),
                    ),
                  ),
                ],
              ),

              // Bottone espandi/comprimi mappa
              InkWell(
                onTap: () => setState(() => isMapExpanded = !isMapExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isMapExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: const Color.fromARGB(206, 255, 255, 255), size: 28),
                      const SizedBox(width: 8),
                      Text(isMapExpanded ? 'Comprimi' : 'Espandi',
                          style: const TextStyle(color: Color.fromARGB(206, 255, 255, 255), fontSize: 14)),
                    ],
                  ),
                ),
              ),

              // Battito e bottoni se mappa non espansa
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
                              child: const Center(child: Text('💛', style: TextStyle(fontSize: 80))),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(currentHeartRate > 0 ? '$currentHeartRate' : '--',
                              style: TextStyle(fontSize: 70, fontWeight: FontWeight.w900, color: deviceColor)),
                          Text('BPM',
                              style: TextStyle(fontSize: 20, color: deviceColor.withOpacity(0.7), letterSpacing: 6)),
                          const SizedBox(height: 30),

                          if (!isConnected)
                            _buildButton(
                                label: 'CONNETTI', icon: Icons.bluetooth_connected,
                                color: const Color.fromARGB(255, 30, 30, 30), onPressed: _connectToDevice),

                          if (isConnected) ...[
                            _buildButton(label: 'AVVIA ATTIVITÀ', icon: Icons.play_arrow, color: Colors.green, onPressed: _startActivity, size: 18),
                            const SizedBox(height: 12),
                            _buildButton(label: isStreaming ? 'FERMA STREAM' : 'AVVIA STREAM',
                                icon: isStreaming ? Icons.stop_circle : Icons.cloud_upload,
                                color: isStreaming ? Colors.red : const Color.fromARGB(255, 78, 0, 109),
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

          // Battito sopra mappa espansa
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
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
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

  // Bottone personalizzato
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

// Dialog per countdown partenza attività
class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({Key? key}) : super(key: key);

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

  // countdown e animazioni
  void _startCountdown() async {
    for (int i = 3; i > 0; i--) {
      if (mounted) {
        setState(() => countdown = i);
        _controller.forward(from: 0);
      }
      await Future.delayed(const Duration(seconds: 1));
    }

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
                        ? const Color.fromARGB(255, 255, 210, 31).withOpacity(0.7)
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
                        color: const Color.fromARGB(255, 255, 210, 31),
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