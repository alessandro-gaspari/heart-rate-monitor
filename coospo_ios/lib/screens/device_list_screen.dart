import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'device_detail_screen.dart';
import 'activities_archive_screen.dart';


enum CoospoDeviceType { 
  none, 
  heartRateBand,
  cadenceSensor,
  speedSensor,
  powerMeter,
  combo,
  unknown
}

CoospoDeviceType getCoospoDeviceType(String deviceName) {
  deviceName = deviceName.toLowerCase();
  
  if (!deviceName.contains('coospo') && 
      !deviceName.contains('808') && 
      !deviceName.contains('h6') && 
      !deviceName.contains('h7') &&
      !deviceName.contains('bc') &&
      !deviceName.contains('cs') &&
      !deviceName.contains('pm')) {
    return CoospoDeviceType.none;
  }
  
  if (deviceName.contains('heart') || 
      deviceName.contains('h6') || 
      deviceName.contains('h7') || 
      deviceName.contains('808') ||
      deviceName.contains('hr')) {
    return CoospoDeviceType.heartRateBand;
  }
  
  if (deviceName.contains('cadence') || 
      deviceName.contains('cad') || 
      deviceName.contains('bc')) {
    return CoospoDeviceType.cadenceSensor;
  }
  
  if (deviceName.contains('speed') || 
      deviceName.contains('spd') || 
      deviceName.contains('cs')) {
    return CoospoDeviceType.speedSensor;
  }
  
  if (deviceName.contains('power') || 
      deviceName.contains('pm')) {
    return CoospoDeviceType.powerMeter;
  }
  
  if (deviceName.contains('combo') || 
      deviceName.contains('bk')) {
    return CoospoDeviceType.combo;
  }
  
  return CoospoDeviceType.unknown;
}

Color getCoospoColor(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand:
      return const Color(0xFFFF4444);
    case CoospoDeviceType.cadenceSensor:
      return const Color(0xFFFF8C00);
    case CoospoDeviceType.speedSensor:
      return const Color(0xFF00BCD4);
    case CoospoDeviceType.powerMeter:
      return const Color(0xFF9B59B6);
    case CoospoDeviceType.combo:
      return const Color(0xFFFFC107);
    case CoospoDeviceType.unknown:
      return const Color(0xFF4CAF50);
    default:
      return const Color(0xFF3498DB);
  }
}

IconData getCoospoIcon(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand:
      return Icons.favorite;
    case CoospoDeviceType.cadenceSensor:
      return Icons.pedal_bike;
    case CoospoDeviceType.speedSensor:
      return Icons.speed;
    case CoospoDeviceType.powerMeter:
      return Icons.flash_on;
    case CoospoDeviceType.combo:
      return Icons.compare_arrows;
    case CoospoDeviceType.unknown:
      return Icons.bluetooth;
    default:
      return Icons.bluetooth;
  }
}

String getCoospoLabel(CoospoDeviceType type) {
  switch (type) {
    case CoospoDeviceType.heartRateBand:
      return 'Heart Rate Monitor';
    case CoospoDeviceType.cadenceSensor:
      return 'Cadence Sensor';
    case CoospoDeviceType.speedSensor:
      return 'Speed Sensor';
    case CoospoDeviceType.powerMeter:
      return 'Power Meter';
    case CoospoDeviceType.combo:
      return 'Speed + Cadence';
    case CoospoDeviceType.unknown:
      return 'COOSPO Device';
    default:
      return 'BLE Device';
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  _DeviceListScreenState createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> 
    with SingleTickerProviderStateMixin {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  String _gpsQuality = 'Sconosciuto';
  Color _gpsColor = Colors.grey;
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _checkGPS();
    
    _radarController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  Future<void> _checkGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        setState(() {
          _gpsQuality = 'Disabilitato';
          _gpsColor = Colors.red;
        });
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      double accuracy = position.accuracy;
      
      if (accuracy <= 10) {
        setState(() {
          _gpsQuality = 'Ottimo';
          _gpsColor = Colors.green;
        });
      } else if (accuracy <= 30) {
        setState(() {
          _gpsQuality = 'Medio';
          _gpsColor = Colors.orange;
        });
      } else {
        setState(() {
          _gpsQuality = 'Scarso';
          _gpsColor = Colors.red;
        });
      }
    } catch (e) {
      print('Errore GPS: $e');
      setState(() {
        _gpsQuality = 'Non disponibile';
        _gpsColor = Colors.grey;
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });
    
    _radarController.repeat();

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results..sort((a, b) {
            var aType = getCoospoDeviceType(a.device.platformName);
            var bType = getCoospoDeviceType(b.device.platformName);
            
            if (aType != CoospoDeviceType.none && bType == CoospoDeviceType.none) return -1;
            if (aType == CoospoDeviceType.none && bType != CoospoDeviceType.none) return 1;
            
            return aType.index.compareTo(bType.index);
          });
        });
      });

      await Future.delayed(const Duration(seconds: 10));
      await _stopScan();
    } catch (e) {
      print('Errore scansione: $e');
      await _stopScan();
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    _radarController.stop();
    setState(() {
      _isScanning = false;
    });
  }

  void _connectToDevice(BluetoothDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailScreen(device: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 0,
        title: Image.asset(
          'assets/craiyon_105658_image.png',
          height: 130,
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Color.fromARGB(255,255,210,31), size: 28),
            color: const Color.fromARGB(255,30,30,30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            offset: const Offset(0, 50),
            onSelected: (value) {
              if (value == 'archive') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActivitiesArchiveScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.run_circle_outlined, color: Color.fromARGB(255, 255, 210, 31), size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Registro Attività',
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 210, 31),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _gpsColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gpsColor, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gps_fixed, color: _gpsColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'GPS: $_gpsQuality',
                  style: TextStyle(
                    color: _gpsColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: _isScanning ? null : _startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(255,255,210,31),
                foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: _isScanning ? const Color.fromARGB(30, 0, 0, 0) : const Color.fromARGB(255,255,210,31),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RotationTransition(
                    turns: _radarController,
                    child: Icon(
                      Icons.radar,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isScanning ? 'SCANSIONE IN CORSO...' : 'CERCA DISPOSITIVI',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          
          const SizedBox(height: 20),
          
          Expanded(
            child: _scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 100,
                          color: const Color.fromARGB(255, 255, 210, 31),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Nessun dispositivo trovato',
                          style: TextStyle(
                            fontSize: 20,
                            color: const Color.fromARGB(255, 255, 210, 31),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Premi il pulsante per iniziare',
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color.fromARGB(255, 255, 210, 31),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      final device = result.device;
                      final deviceType = getCoospoDeviceType(device.platformName);
                      final color = getCoospoColor(deviceType);
                      final icon = getCoospoIcon(deviceType);
                      final label = getCoospoLabel(deviceType);
                      final isCoospo = deviceType != CoospoDeviceType.none;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCoospo
                                ? [color.withOpacity(0.3), color.withOpacity(0.1)]
                                : [const Color.fromARGB(255, 30, 30, 30), const Color.fromARGB(255, 30, 30, 30)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCoospo ? color : Colors.white.withOpacity(0.1),
                            width: isCoospo ? 2 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _connectToDevice(device),
                            borderRadius: BorderRadius.circular(16),
                            splashColor: color.withOpacity(0.2),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(255, 255, 210, 31),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color.fromARGB(255, 255, 210, 31).withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      icon,
                                      color: const Color.fromARGB(255, 30, 30, 30),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.platformName.isEmpty
                                              ? 'Dispositivo sconosciuto'
                                              : device.platformName,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isCoospo ? color : Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (isCoospo) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: color.withOpacity(0.8),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          device.remoteId.toString(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.5),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: isCoospo ? color : Colors.white.withOpacity(0.7),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
