import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_detail_screen.dart';

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
      return const Color(0xFFFF4444);  // Rosso
    case CoospoDeviceType.armband:
      return const Color(0xFFFF8C00);  // Arancione
    case CoospoDeviceType.unknown:
      return const Color(0xFF9B59B6);  // Viola
    default:
      return const Color(0xFF3498DB);  // Blu
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  _DeviceListScreenState createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results..sort((a, b) {
            var aType = getCoospoDeviceType(a.device.platformName);
            var bType = getCoospoDeviceType(b.device.platformName);
            if (aType != CoospoDeviceType.none && bType == CoospoDeviceType.none) return -1;
            if (aType == CoospoDeviceType.none && bType != CoospoDeviceType.none) return 1;
            return 0;
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
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'Dispositivi BLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Pulsante Scansione
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: _isScanning ? null : _startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.grey.shade700 : const Color(0xFF1E90FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: _isScanning ? Colors.transparent : const Color(0xFF1E90FF).withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isScanning ? Icons.hourglass_empty : Icons.radar,
                    size: 26,
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
          
          if (_isScanning) ...[
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E90FF)),
              strokeWidth: 4,
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Lista dispositivi
          Expanded(
            child: _scanResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 100,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Nessun dispositivo trovato',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Premi il pulsante per iniziare',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.4),
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
                      final isCoospo = deviceType != CoospoDeviceType.none;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCoospo
                                ? [color.withOpacity(0.3), color.withOpacity(0.1)]
                                : [const Color(0xFF1D1E33), const Color(0xFF1D1E33)],
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
                                      color: color,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isCoospo ? Icons.favorite : Icons.bluetooth,
                                      color: Colors.white,
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
                                    color: isCoospo ? color : Colors.white.withOpacity(0.3),
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

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }
}
