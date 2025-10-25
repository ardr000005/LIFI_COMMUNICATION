import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;
  StreamSubscription<List<int>>? _subscription;

  static const String serviceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String txCharacteristicUUID =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharacteristicUUID =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

  String get connectedDeviceName => _connectedDevice?.platformName ?? "Unknown";
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Check and request necessary permissions
  Future<bool> _checkPermissions() async {
    try {
      // Check Bluetooth status first
      BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        throw Exception("Please turn on Bluetooth");
      }

      // Request permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
      ].request();

      // Check if all permissions are granted
      if (statuses[Permission.bluetooth] != PermissionStatus.granted ||
          statuses[Permission.bluetoothConnect] != PermissionStatus.granted ||
          statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
          statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
        throw Exception("Bluetooth and Location permissions are required");
      }

      return true;
    } catch (e) {
      print("Permission check error: $e");
      rethrow;
    }
  }

  // Get all bonded (paired) devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      await _checkPermissions();

      List<BluetoothDevice> bondedDevices = [];

      // Get connected devices (these are usually bonded)
      List<BluetoothDevice> connectedDevices =
          await FlutterBluePlus.connectedDevices;
      bondedDevices.addAll(connectedDevices);

      print("Found ${bondedDevices.length} bonded/connected devices");

      return bondedDevices;
    } catch (e) {
      print("Error getting bonded devices: $e");
      rethrow;
    }
  }

  // Scan for all available devices (both bonded and new)
  Future<List<BluetoothDevice>> scanForAllDevices() async {
    StreamSubscription<List<ScanResult>>? scanSubscription;

    try {
      await _checkPermissions();

      List<BluetoothDevice> foundDevices = [];
      Set<String> seenDeviceIds = {};

      // Stop any existing scan
      await FlutterBluePlus.stopScan();

      print("Starting Bluetooth scan...");

      // Listen for scan results
      final completer = Completer<void>();
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          String deviceName = result.device.platformName;
          String deviceId = result.device.remoteId.toString();

          // Skip duplicates
          if (seenDeviceIds.contains(deviceId)) {
            continue;
          }

          seenDeviceIds.add(deviceId);
          foundDevices.add(result.device);

          String advName = result.advertisementData.localName;
          print(
              "Found device: '$deviceName' | Adv Name: '$advName' | ID: $deviceId | RSSI: ${result.rssi}");
        }
      }, onError: (error) {
        print("Scan error: $error");
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      // Start scanning with proper settings
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false,
      );

      print("Scanning for devices...");

      // Wait for scan duration
      await Future.delayed(const Duration(seconds: 8));

      // Stop scanning
      await FlutterBluePlus.stopScan();
      await scanSubscription.cancel();

      print("Scan completed. Found ${foundDevices.length} total devices");

      // Remove duplicates by device ID
      final uniqueDevices = <String, BluetoothDevice>{};
      for (var device in foundDevices) {
        uniqueDevices[device.remoteId.toString()] = device;
      }

      return uniqueDevices.values.toList();
    } catch (e) {
      print("Scan error: $e");
      await FlutterBluePlus.stopScan();
      await scanSubscription?.cancel();
      rethrow;
    }
  }

  // Connect to any BLE device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await _checkPermissions();

      print("Connecting to device: ${device.platformName}");

      // Connect to device with autoConnect disabled for faster connection
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      _connectedDevice = device;

      print("Connected, discovering services...");

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      bool serviceFound = false;
      bool txFound = false;
      bool rxFound = false;

      print("Discovered ${services.length} services");

      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toUpperCase();
        print("Service: $serviceUuid");

        // Look for Nordic UART Service (common for ESP32 BLE)
        if (serviceUuid == serviceUUID) {
          serviceFound = true;
          print("✅ Found Li-Fi service");

          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toUpperCase();
            print("Characteristic: $charUuid");

            if (charUuid == txCharacteristicUUID) {
              _txCharacteristic = characteristic;
              txFound = true;
              print("✅ Found TX characteristic");
            } else if (charUuid == rxCharacteristicUUID) {
              _rxCharacteristic = characteristic;
              rxFound = true;
              print("✅ Found RX characteristic");
            }
          }
        }
      }

      if (!serviceFound) {
        print("⚠️ Li-Fi service not found, but connected successfully");
        // Still return true if connected, even if service not found
        return true;
      }

      print("✅ BLE device setup complete");
      return true;
    } catch (e) {
      print("BLE connection error: $e");
      await device.disconnect();
      rethrow;
    }
  }

  Future<bool> sendMessage(String message) async {
    if (_rxCharacteristic == null) {
      print("❌ RX characteristic not available, device may not support Li-Fi");
      return false;
    }

    try {
      final data = utf8.encode(message);
      await _rxCharacteristic!.write(data);
      print("✅ Message sent: ${message.length} bytes");
      return true;
    } catch (e) {
      print("Send error: $e");
      return false;
    }
  }

  void startListening(Function(String) onMessageReceived) {
    if (_txCharacteristic == null) {
      print("❌ TX characteristic not available for listening");
      return;
    }

    _subscription = _txCharacteristic!.onValueReceived.listen((value) {
      try {
        String message = utf8.decode(value);
        print("📨 Received message: $message");
        onMessageReceived(message);
      } catch (e) {
        print("Message decode error: $e");
      }
    });

    _txCharacteristic!.setNotifyValue(true);
    print("✅ Started listening for messages");
  }

  void disconnect() {
    _subscription?.cancel();
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
  }

  bool get isConnected => _connectedDevice != null;
}
