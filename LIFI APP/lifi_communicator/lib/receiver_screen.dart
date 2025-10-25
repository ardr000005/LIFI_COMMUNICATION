import 'package:flutter/material.dart';
import 'dart:async';
import 'bluetooth_manager.dart';
import 'encryption_manager.dart';
import 'message_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final EncryptionManager encryptionManager = EncryptionManager();
  final TextEditingController _keyController = TextEditingController();

  List<Message> messages = [];
  List<BluetoothDevice> availableDevices = [];
  bool isScanning = false;
  bool isConnected = false;
  String connectionStatus = "Disconnected";
  String deviceName = "";

  @override
  void initState() {
    super.initState();
    _loadEncryptionKey();
    _loadBondedDevices();

    // Test encryption on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      encryptionManager.testEncryption("Hello LiFi", _keyController.text);
    });
  }

  @override
  void dispose() {
    bluetoothManager.disconnect();
    super.dispose();
  }

  void _loadEncryptionKey() {
    _keyController.text = "lifi";
  }

  Future<void> _loadBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices =
          await bluetoothManager.getBondedDevices();
      setState(() {
        availableDevices = bondedDevices;
      });
    } catch (e) {
      print("Error loading bonded devices: $e");
    }
  }

  Future<void> _scanForAllDevices() async {
    try {
      setState(() {
        isScanning = true;
        connectionStatus = "Scanning for all Bluetooth devices...";
      });

      List<BluetoothDevice> devices =
          await bluetoothManager.scanForAllDevices();

      setState(() {
        availableDevices = devices;
        isScanning = false;
        connectionStatus =
            devices.isEmpty ? "No devices found" : "Select a device to connect";
      });

      if (devices.isEmpty) {
        _showErrorDialog(
          "No Devices Found",
          "No Bluetooth devices were found.\n\n"
              "Please check:\n"
              "• Bluetooth is turned ON\n"
              "• Devices are in pairing mode\n"
              "• Devices are in range\n"
              "• Location permission is granted",
        );
      }
    } catch (e) {
      setState(() {
        isScanning = false;
        connectionStatus = "Scan failed: ${e.toString()}";
      });
      _showErrorDialog("Scan Error", e.toString());
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        connectionStatus = "Connecting to ${device.platformName}...";
      });

      bool connected = await bluetoothManager.connectToDevice(device);

      if (connected) {
        setState(() {
          isConnected = true;
          deviceName = bluetoothManager.connectedDeviceName;
          connectionStatus = "Connected to ${device.platformName}";
        });

        _startListening();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connected to ${device.platformName}"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          connectionStatus = "Failed to connect";
        });
      }
    } catch (e) {
      setState(() {
        connectionStatus = "Connection failed: ${e.toString()}";
      });
      _showErrorDialog("Connection Error", "Failed to connect: $e");
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _startListening() {
    bluetoothManager.startListening((receivedData) {
      _handleReceivedMessage(receivedData);
    });
  }

  void _handleReceivedMessage(String encryptedData) async {
    try {
      print("🔄 Received encrypted data: ${encryptedData.length} chars");
      print("📝 Data: $encryptedData");

      String decrypted = encryptionManager.decrypt(
        encryptedData,
        _keyController.text,
      );

      print("✅ Successfully decrypted: $decrypted");

      Message message = Message(
        content: decrypted,
        isSent: false,
        timestamp: DateTime.now(),
        encryptedContent: encryptedData,
      );

      setState(() {
        messages.insert(0, message);
      });

      // Show notification for important messages
      if (decrypted.length < 100) {
        _showMessageNotification("📥 Message Received", decrypted);
      }
    } catch (e) {
      print("❌ Decryption error: $e");

      // Still show the encrypted message
      Message message = Message(
        content: "[Encrypted - Can't decrypt: ${e.toString()}]",
        isSent: false,
        timestamp: DateTime.now(),
        encryptedContent: encryptedData,
      );
      setState(() {
        messages.insert(0, message);
      });

      _showErrorDialog("Decryption Error", "Failed to decrypt message: $e");
    }
  }

  void _showMessageNotification(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
            content.length > 100 ? "${content.substring(0, 100)}..." : content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _disconnect() {
    bluetoothManager.disconnect();
    setState(() {
      isConnected = false;
      connectionStatus = "Disconnected";
      deviceName = "";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Disconnected from device"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _clearMessages() {
    setState(() {
      messages.clear();
    });
  }

  Widget _buildMessageBubble(Message message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inbox, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Text(
                        "Received",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.lock, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (message.encryptedContent.isNotEmpty)
                    const SizedBox(height: 4),
                  if (message.encryptedContent.isNotEmpty)
                    Text(
                      "Encrypted: ${message.encryptedContent.length > 30 ? '${message.encryptedContent.substring(0, 30)}...' : message.encryptedContent}",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Receiver Mode"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearMessages,
              tooltip: "Clear Messages",
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Connection Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isConnected
                                ? Icons.bluetooth_connected
                                : isScanning
                                    ? Icons.search
                                    : Icons.bluetooth,
                            color: isConnected
                                ? Colors.green
                                : isScanning
                                    ? Colors.orange
                                    : Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connectionStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isConnected
                                        ? Colors.green
                                        : isScanning
                                            ? Colors.orange
                                            : Colors.blue,
                                  ),
                                ),
                                if (deviceName.isNotEmpty)
                                  Text(
                                    "Device: $deviceName",
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                if (isConnected)
                                  const Text(
                                    "Listening for Li-Fi messages...",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!isConnected)
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: isScanning ? null : _scanForAllDevices,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: isScanning
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text("Scanning..."),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search),
                                        SizedBox(width: 8),
                                        Text("Scan All Devices"),
                                      ],
                                    ),
                            ),
                            if (availableDevices.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                "Available Devices:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...availableDevices
                                  .map((device) => Card(
                                        color: Colors.green.shade50,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: const Icon(Icons.bluetooth,
                                              color: Colors.green),
                                          title: Text(
                                            device.platformName.isNotEmpty
                                                ? device.platformName
                                                : "Unknown Device",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            device.remoteId.toString(),
                                            style: TextStyle(
                                                color: Colors.grey.shade600),
                                          ),
                                          trailing: const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16),
                                          onTap: () => _connectToDevice(device),
                                        ),
                                      ))
                                  .toList(),
                            ],
                          ],
                        )
                      else
                        ElevatedButton(
                          onPressed: _disconnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text("Disconnect"),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Encryption Key Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vpn_key, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Encryption Key",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _keyController,
                        decoration: const InputDecoration(
                          hintText: "Enter encryption key",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          // Update key in real-time
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Same key must be used on both transmitter and receiver",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Connection Info Card (only when connected)
              if (isConnected) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ready to Receive",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "The receiver ESP32 will automatically detect Li-Fi signals and send them to this app",
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Received Messages Card
              Card(
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inbox, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "Received Messages",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          if (messages.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${messages.length}",
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: messages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.wifi_find_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isConnected
                                          ? "Waiting for Li-Fi signals..."
                                          : "No messages received yet",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isConnected
                                          ? "Ensure Li-Fi transmitter is aligned with receiver"
                                          : "Connect to a receiver device first",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  return _buildMessageBubble(messages[index]);
                                },
                              ),
                      ),
                    ],
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
