import 'package:flutter/material.dart';
import 'dart:async';
import 'bluetooth_manager.dart';
import 'encryption_manager.dart';
import 'message_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class TransmitterScreen extends StatefulWidget {
  const TransmitterScreen({super.key});

  @override
  State<TransmitterScreen> createState() => _TransmitterScreenState();
}

class _TransmitterScreenState extends State<TransmitterScreen> {
  final BluetoothManager bluetoothManager = BluetoothManager();
  final EncryptionManager encryptionManager = EncryptionManager();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  List<Message> messages = [];
  List<BluetoothDevice> availableDevices = [];
  bool isScanning = false;
  bool isConnected = false;
  bool isSending = false;
  String connectionStatus = "Disconnected";
  String deviceName = "";

  @override
  void initState() {
    super.initState();
    _loadEncryptionKey();
    _loadBondedDevices();
    _setupBluetoothListener();

    // Test encryption on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      encryptionManager.testEncryption("Hello LiFi", _keyController.text);
    });
  }

  @override
  void dispose() {
    bluetoothManager.disconnect();
    _messageController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _setupBluetoothListener() {
    FlutterBluePlus.adapterState.listen((state) {
      print("Bluetooth adapter state: $state");
      if (mounted) {
        setState(() {
          if (state != BluetoothAdapterState.on) {
            isConnected = false;
            connectionStatus = "Bluetooth is off";
          }
        });
      }
    });
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
        isConnected = false;
      });

      bool connected = await bluetoothManager.connectToDevice(device);

      if (connected) {
        setState(() {
          isConnected = true;
          deviceName = bluetoothManager.connectedDeviceName;
          connectionStatus = "Connected to ${device.platformName}";
        });

        print("✅ Device connected successfully. isConnected: $isConnected");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connected to ${device.platformName}"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          isConnected = false;
          connectionStatus = "Failed to connect - service not found";
        });
        print("❌ Connection failed - service not found");
      }
    } catch (e) {
      setState(() {
        isConnected = false;
        connectionStatus = "Connection failed: ${e.toString()}";
      });
      print("❌ Connection error: $e");
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

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || !isConnected) {
      print("❌ Cannot send message: empty text or not connected");
      print("   - isConnected: $isConnected");
      print("   - text length: ${_messageController.text.length}");
      _showErrorDialog(
          "Cannot Send",
          _messageController.text.isEmpty
              ? "Please enter a message"
              : "Not connected to any device");
      return;
    }

    String plainText = _messageController.text;

    setState(() {
      isSending = true;
    });

    try {
      print("🔄 Encrypting message...");
      String encrypted = encryptionManager.encrypt(
        plainText,
        _keyController.text,
      );

      print(
          "Original: ${plainText.length} chars, Encrypted: ${encrypted.length} chars");
      print("Encrypted data: $encrypted");

      print("🔄 Sending message via Bluetooth...");
      bool success = await bluetoothManager.sendMessage(encrypted);

      if (success) {
        Message message = Message(
          content: plainText,
          isSent: true,
          timestamp: DateTime.now(),
          encryptedContent: encrypted,
        );

        setState(() {
          messages.insert(0, message);
          _messageController.clear();
        });

        print("✅ Message sent successfully");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Message sent successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print("❌ Failed to send message");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send message"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ Send message error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSending = false;
      });
    }
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

  Future<void> _testConnection() async {
    try {
      bool success = await bluetoothManager.sendMessage("PING");
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Connection test successful"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Connection test failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection test error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transmitter Mode"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.wifi_find),
              onPressed: _testConnection,
              tooltip: "Test Connection",
            ),
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
                                  Text(
                                    "Ready to transmit",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "CONNECTED",
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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
                                backgroundColor: Colors.blue,
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
                                        color: Colors.blue.shade50,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: const Icon(Icons.bluetooth,
                                              color: Colors.blue),
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
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _disconnect,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50),
                                ),
                                child: const Text("Disconnect"),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Only show message input when connected
              if (isConnected) ...[
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

                // Message Input Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.message, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Send Message via Li-Fi",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _messageController,
                          maxLines: 3,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: const InputDecoration(
                            labelText: "Type your message",
                            border: OutlineInputBorder(),
                            hintText: "Enter message to transmit via Li-Fi...",
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: isConnected &&
                                  !isSending &&
                                  _messageController.text.isNotEmpty
                              ? _sendMessage
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected &&
                                    !isSending &&
                                    _messageController.text.isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      color: isConnected &&
                                              !isSending &&
                                              _messageController.text.isNotEmpty
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Transmit via Li-Fi",
                                      style: TextStyle(
                                        color: isConnected &&
                                                !isSending &&
                                                _messageController
                                                    .text.isNotEmpty
                                            ? Colors.white
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (!isConnected) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Not connected to any device",
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ] else if (_messageController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Enter a message to enable transmission",
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sent Messages Card
              Card(
                child: Container(
                  height: 300,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Sent Messages",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      "No messages sent yet",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  return MessageBubble(
                                      message: messages[index]);
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

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.outgoing_mail,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      const Text(
                        "Sent",
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
                  Text(message.content, style: const TextStyle(fontSize: 16)),
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
}
