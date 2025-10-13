import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gps_service.dart';
import 'device_detail_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  final GpsService _gpsService = GpsService();
  GpsSignalQuality _currentGpsSignal = GpsSignalQuality.noSignal;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
    _initGps();
  }

  void _initGps() {
    _gpsService.startMonitoring();
    _gpsService.signalStream.listen((quality) {
      if (mounted) {
        setState(() {
          _currentGpsSignal = quality;
        });
      }
    });
  }

  Future<void> _checkBluetoothState() async {
    if (await FlutterBluePlus.isSupported == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth non supportato su questo dispositivo')),
        );
      }
      return;
    }
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.stopScan();

    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            scanResults = results;
          });
        }
      });

      await Future.delayed(const Duration(seconds: 15));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore scansione: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  bool _isCoospoDevice(ScanResult result) {
    final advName = result.advertisementData.advName.toUpperCase();
    if (advName.contains('COOSPO') ||
        advName.contains('H6') ||
        advName.contains('H808') ||
        advName.contains('HW807') ||
        advName.contains('HW706') ||
        advName.contains('HW9')) {
      return true;
    }

    final platformName = result.device.platformName.toUpperCase();
    if (platformName.contains('COOSPO') ||
        platformName.contains('H6') ||
        platformName.contains('H808') ||
        platformName.contains('HW807') ||
        platformName.contains('HW706') ||
        platformName.contains('HW9')) {
      return true;
    }

    final services = result.advertisementData.serviceUuids;
    bool hasHeartRateService = services.any(
        (uuid) => uuid.toString().toLowerCase().contains('180d'));

    final manufacturerData = result.advertisementData.manufacturerData;

    if (hasHeartRateService && manufacturerData.isNotEmpty) {
      return true;
    }

    return false;
  }

  String _getDeviceName(ScanResult result) {
    if (_isCoospoDevice(result)) {
      return '❤️ Cardiofrequenzimetro COOSPO';
    }

    if (result.advertisementData.advName.isNotEmpty) {
      String name = result.advertisementData.advName;
      if (name.toUpperCase().contains('COOSPO') ||
          name.toUpperCase().contains('H6') ||
          name.toUpperCase().contains('H808') ||
          name.toUpperCase().contains('HW')) {
        return '❤️ Cardiofrequenzimetro COOSPO';
      }
      return name;
    }

    if (result.device.platformName.isNotEmpty) {
      String name = result.device.platformName;
      if (name.toUpperCase().contains('COOSPO') ||
          name.toUpperCase().contains('H6') ||
          name.toUpperCase().contains('H808') ||
          name.toUpperCase().contains('HW')) {
        return '❤️ Cardiofrequenzimetro COOSPO';
      }
      return name;
    }

    return 'Dispositivo ${result.device.remoteId.str.substring(result.device.remoteId.str.length - 8)}';
  }

  String _getDeviceType(ScanResult result) {
    if (_isCoospoDevice(result)) {
      return 'Sensore cardio Bluetooth/ANT+';
    }

    final services = result.advertisementData.serviceUuids;

    if (services.any((uuid) => uuid.toString().toLowerCase().contains('180f'))) {
      return '🔋 Sensore batteria';
    }
    if (services.any((uuid) => uuid.toString().toLowerCase().contains('180d'))) {
      return '❤️ Cardiofrequenzimetro';
    }
    if (services.any((uuid) => uuid.toString().toLowerCase().contains('1816'))) {
      return '🚴 Sensore velocità/cadenza';
    }
    if (services.any((uuid) => uuid.toString().toLowerCase().contains('1818'))) {
      return '🚴 Power meter';
    }

    return '📱 Dispositivo BLE';
  }

  void _navigateToDeviceDetail(BluetoothDevice device, bool isCoospo) async {
    await FlutterBluePlus.stopScan();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceDetailScreen(
            device: device,
            isCoospo: isCoospo,
          ),
        ),
      );
    }
  }

  Color _getGpsColor() {
    switch (_currentGpsSignal) {
      case GpsSignalQuality.excellent:
        return Colors.green;
      case GpsSignalQuality.good:
        return Colors.lightGreen;
      case GpsSignalQuality.moderate:
        return Colors.yellow;
      case GpsSignalQuality.weak:
        return Colors.orange;
      case GpsSignalQuality.veryWeak:
        return Colors.deepOrange;
      case GpsSignalQuality.noSignal:
        return Colors.red;
    }
  }

  String _getGpsText() {
    switch (_currentGpsSignal) {
      case GpsSignalQuality.excellent:
        return 'Eccellente';
      case GpsSignalQuality.good:
        return 'Buono';
      case GpsSignalQuality.moderate:
        return 'Moderato';
      case GpsSignalQuality.weak:
        return 'Debole';
      case GpsSignalQuality.veryWeak:
        return 'Molto debole';
      case GpsSignalQuality.noSignal:
        return 'Nessun segnale';
    }
  }

  IconData _getGpsIcon() {
    switch (_currentGpsSignal) {
      case GpsSignalQuality.excellent:
      case GpsSignalQuality.good:
        return Icons.gps_fixed;
      case GpsSignalQuality.moderate:
        return Icons.gps_not_fixed;
      case GpsSignalQuality.weak:
      case GpsSignalQuality.veryWeak:
      case GpsSignalQuality.noSignal:
        return Icons.gps_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivi Bluetooth'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Indicatore GPS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _getGpsColor().withOpacity(0.15),
              border: Border(
                bottom:
                    BorderSide(color: _getGpsColor().withOpacity(0.3), width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getGpsIcon(), color: _getGpsColor(), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Segnale GPS: ${_getGpsText()}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: _getGpsColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: isScanning ? null : _startScan,
                  icon: isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(
                    isScanning ? 'Scansione in corso...' : 'Scansiona dispositivi',
                    style: GoogleFonts.montserrat(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 8),
                if (scanResults.isNotEmpty)
                  Text(
                    '${scanResults.length} dispositivi trovati',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),

          Expanded(
            child: scanResults.isEmpty
                ? Center(
                    child: Text(
                      isScanning
                          ? 'Ricerca dispositivi Coospo...'
                          : 'Nessun dispositivo trovato.\nPremi il pulsante per scansionare.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: scanResults.length,
                    itemBuilder: (context, index) {
                      final result = scanResults[index];
                      final deviceName = _getDeviceName(result);
                      final deviceType = _getDeviceType(result);
                      final isCoospo = _isCoospoDevice(result);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: isCoospo ? const Color(0xFF2C3E50) : null,
                        child: ListTile(
                          leading: Icon(
                            isCoospo ? Icons.favorite : Icons.bluetooth,
                            color: isCoospo ? Colors.red : Colors.blue,
                            size: 32,
                          ),
                          title: Text(
                            deviceName,
                            style: GoogleFonts.montserrat(
                              fontWeight:
                                  isCoospo ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: isCoospo ? Colors.white : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceType,
                                style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: isCoospo ? Colors.white70 : null),
                              ),
                              Text(
                                'Segnale: ${result.rssi} dBm',
                                style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: isCoospo ? Colors.white70 : null),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: isCoospo ? Colors.white : Colors.grey,
                            size: 20,
                          ),
                          onTap: () =>
                              _navigateToDeviceDetail(result.device, isCoospo),
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
