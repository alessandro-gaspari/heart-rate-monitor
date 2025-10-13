import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'device_detail_screen.dart';
import '../widgets/gps_status_widget.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  Position? currentPosition;
  Timer? _positionTimer;
  bool _permissionsGranted = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePermissions();
    });
  }

  Future<void> _initializePermissions() async {
    setState(() => _isInitializing = true);

    try {
      // Verifica che il Bluetooth sia disponibile e attivo
      if (!await FlutterBluePlus.isAvailable) {
        _showError('Il Bluetooth non è disponibile su questo dispositivo');
        return;
      }

      // Controlla se il Bluetooth è attivo
      if (!await FlutterBluePlus.adapterState.first.then((state) => state == BluetoothAdapterState.on)) {
        _showError('Per favore, attiva il Bluetooth');
        return;
      }

      // Verifica permessi di localizzazione
      bool locationGranted = await _checkLocationPermission();
      if (!locationGranted) return;

      // Se tutti i permessi sono OK, procedi
      setState(() {
        _permissionsGranted = true;
        _isInitializing = false;
      });
      
      _startLocationUpdates();
      startScan();
    } catch (e) {
      _showError('Errore durante l\'inizializzazione: $e');
      setState(() => _isInitializing = false);
    }
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('I servizi di localizzazione sono disattivati');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('I permessi di localizzazione sono necessari');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('I permessi di localizzazione sono stati negati permanentemente');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    setState(() => _isInitializing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Riprova',
            textColor: Colors.white,
            onPressed: _initializePermissions,
          ),
        ),
      );
    }
  }

  void _startLocationUpdates() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() => currentPosition = position);
        }
      } catch (e) {
        debugPrint('Errore posizione: $e');
      }
    });
  }

  Future<void> startScan() async {
    if (!_permissionsGranted) {
      _initializePermissions();
      return;
    }

    // Cancella la lista dei dispositivi prima di ogni scansione
    setState(() {
      scanResults = [];
      isScanning = true;
    });

    try {
      // Ferma eventuali scansioni in corso
      if (await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
      }
      
      // Inizia una nuova scansione
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: true,
      );

      // Ascolta i risultati della scansione e aggiorna la lista
      FlutterBluePlus.scanResults.listen(
        (results) {
          if (mounted) {
            // Filtra solo i dispositivi attualmente raggiungibili
            final uniqueDevices = <String, ScanResult>{};
            for (var result in results) {
              uniqueDevices[result.device.remoteId.str] = result;
            }
            setState(() => scanResults = uniqueDevices.values.toList());
          }
        },
        onError: (e) {
          _showError('Errore durante la scansione: $e');
          setState(() => isScanning = false);
        },
      );

      FlutterBluePlus.isScanning.listen(
        (scanning) {
          if (mounted) {
            setState(() => isScanning = scanning);
          }
        },
      );
    } catch (e) {
      _showError('Errore durante la scansione: $e');
      setState(() => isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.bluetooth,
              color: Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Dispositivi Bluetooth',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.blue,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF2C2C2C),
            child: Row(
              children: [
                const GpsStatusWidget(),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _permissionsGranted ? startScan : _initializePermissions,
        icon: Icon(isScanning ? Icons.stop : Icons.search),
        label: Text(
          isScanning ? 'Ferma' : 'Cerca',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text('Inizializzazione...'),
          ],
        ),
      );
    }

    if (!_permissionsGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('I permessi richiesti non sono stati concessi'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializePermissions,
              child: const Text('Concedi Permessi'),
            ),
          ],
        ),
      );
    }

    if (scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.blue.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun dispositivo trovato',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Premi il pulsante per cercare',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: scanResults.length,
      itemBuilder: (context, index) {
        final result = scanResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          color: const Color(0xFF2C2C2C),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              result.device.name.isEmpty
                  ? 'Dispositivo Sconosciuto'
                  : result.device.name,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                result.device.id.id,
                style: GoogleFonts.montserrat(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${result.rssi} dBm',
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.signal_cellular_alt,
                    color: result.rssi > -70
                        ? Colors.green
                        : result.rssi > -90
                            ? Colors.yellow
                            : Colors.red,
                  ),
                ],
              ),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth,
                color: Colors.blue,
                size: 24,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DeviceDetailScreen(device: result.device),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}