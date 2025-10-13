import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bluetooth_connection_service.dart';

class DeviceDetailScreen extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final BluetoothConnectionService _bluetoothService = BluetoothConnectionService();
  bool isConnecting = false;
  bool isConnected = false;
  String connectionStatus = 'Disconnesso';
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  List<BluetoothService> services = [];

  @override
  void initState() {
    super.initState();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _stateSubscription = widget.device.connectionState.listen(
      (state) {
        if (mounted) {
          setState(() {
            isConnected = state == BluetoothConnectionState.connected;
            switch (state) {
              case BluetoothConnectionState.connected:
                connectionStatus = 'Connesso';
                _discoverServices();
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
                services.clear();
                break;
            }
          });
        }
      },
      onError: (error) {
        _showError('Errore di connessione: $error');
      },
    );
  }

  Future<void> _discoverServices() async {
    try {
      services = await widget.device.discoverServices();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Errore durante la scoperta dei servizi: $e');
    }
  }

  Future<void> connectToDevice() async {
    if (isConnecting || isConnected) return;

    setState(() {
      isConnecting = true;
      connectionStatus = 'Tentativo di connessione...';
    });

    try {
      final success = await _bluetoothService.connectToDevice(widget.device);
      
      if (!success) {
        throw Exception('Connessione non riuscita');
      }

      if (mounted) {
        setState(() {
          isConnecting = false;
          isConnected = true;
          connectionStatus = 'Connesso';
        });
        _showSuccess('Dispositivo connesso con successo');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isConnecting = false;
          isConnected = false;
          connectionStatus = 'Errore di connessione';
        });
        _showError('Errore: ${e.toString()}');
      }
    }
  }

  Future<void> disconnectFromDevice() async {
    try {
      setState(() => connectionStatus = 'Disconnessione...');
      await _bluetoothService.disconnectFromDevice(widget.device);
      if (mounted) {
        setState(() {
          isConnected = false;
          connectionStatus = 'Disconnesso';
          services.clear();
        });
      }
    } catch (e) {
      _showError('Errore durante la disconnessione: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isConnected) {
          await disconnectFromDevice();
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.device.platformName.isEmpty
                      ? 'Dispositivo Sconosciuto'
                      : widget.device.platformName,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_connected,
                      size: 80,
                      color: isConnected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ID Dispositivo:',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.device.remoteId.str,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isConnecting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          ),
                        if (isConnecting)
                          const SizedBox(width: 8),
                        Text(
                          connectionStatus,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isConnected 
                                ? Colors.green 
                                : isConnecting
                                    ? Colors.blue
                                    : Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    if (services.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Servizi disponibili: ${services.length}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: isConnecting 
                    ? null 
                    : (isConnected ? disconnectFromDevice : connectToDevice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isConnected ? Icons.bluetooth_disabled : Icons.bluetooth_connected,
                  size: 24,
                ),
                label: Text(
                  isConnected ? 'Disconnetti' : 'Connetti',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    if (isConnected) {
      _bluetoothService.disconnectFromDevice(widget.device);
    }
    super.dispose();
  }
}