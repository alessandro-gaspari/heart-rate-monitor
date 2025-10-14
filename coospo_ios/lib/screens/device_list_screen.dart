import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device_detail_screen.dart';

// Enum per tipi COOSPO
enum CoospoDeviceType { none, heartRateBand, armband, unknown }

// Funzioni helper
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
    case CoospoDeviceType.heartRateBand:
      return Colors.red;
    case CoospoDeviceType.armband:
      return Colors.orange;
    case CoospoDeviceType.unknown:
      return Colors.purple;
    case CoospoDeviceType.none:
    default:
      return const Color(0xFF667eea);
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
            bool aIsCoospo = a.device.platformName.toUpperCase().contains('COOSPO');
            bool bIsCoospo = b.device.platformName.toUpperCase().contains('COOSPO');
            if (aIsCoospo && !bIsCoospo) return -1;
            if (!aIsCoospo && bIsCoospo) return 1;
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
      appBar: AppBar(
        title: const Text('Dispositivi BLE'),
        backgroundColor: const Color(0xFF667eea),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667eea).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.search),
                label: Text(_isScanning ? 'Scansione in corso...' : 'Cerca Dispositivi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ),
            if (_isScanning)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nessun dispositivo trovato',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Premi il pulsante per iniziare la ricerca',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        final result = _scanResults[index];
                        final device = result.device;
                        final deviceType = getCoospoDeviceType(device.platformName);
                        final color = getCoospoColor(deviceType);
                        
                        return Card(
                          elevation: deviceType != CoospoDeviceType.none ? 8 : 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: deviceType != CoospoDeviceType.none
                                ? BorderSide(color: color, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _connectToDevice(device),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: deviceType != CoospoDeviceType.none
                                    ? LinearGradient(
                                        colors: [
                                          color.withOpacity(0.2),
                                          color.withOpacity(0.05),
                                        ],
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      deviceType == CoospoDeviceType.none ? Icons.bluetooth : Icons.favorite,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.platformName.isEmpty ? 'Dispositivo sconosciuto' : device.platformName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          device.remoteId.toString(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: color,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }
}
