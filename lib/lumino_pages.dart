// lumino_pages.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

// --- Configuration ---
const String LUMINO_DEVICE_NAME = "Lumino";
const String LP_PWM_SERVICE_UUID = "8e2a9190-7a6f-4e60-9fb9-2262a8d35112";
const String LP_PWM_CHAR_UUID = "8e2a9191-7a6f-4e60-9fb9-2262a8d35112";

// Global variable to hold the connected device reference
BluetoothDevice? connectedLuminoDevice;

// --- State Class for the Control Page ---
// (Remains the same)
class LuminoControlData {
  DateTime currentDateTime;
  DateTime alarmDateTime;
  double dimmingValue;

  LuminoControlData({
    required this.currentDateTime,
    required this.alarmDateTime,
    this.dimmingValue = 0.0,
  });
}

// --- Start Page (First Page) ---
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  String _connectionStatus = "Ready to connect.";
  bool _isConnecting = false;

  Future<bool> _requestPermissions() async {
    // 1. Bluetooth Permissions Check
    var scanStatus = await Permission.bluetoothScan.request();
    var connectStatus = await Permission.bluetoothConnect.request();

    // Check if the Nearby Devices permission (which includes SCAN/CONNECT) was granted
    if (!scanStatus.isGranted || !connectStatus.isGranted) {
      _showError('Nearby devices permission denied. Opening App Settings...');
      // Direct the user to the app settings to manually grant permission
      openAppSettings();
      return false;
    }

    // 2. Location Permission Check (Fallback for Scan Issues)
    var locationStatus = await Permission.locationWhenInUse.request();

    if (locationStatus.isPermanentlyDenied) {
      _showError('Location permission permanently denied. Opening App Settings...');
      openAppSettings();
      return false;
    }
    // We only need to check if the Location Service (GPS) is ON if the permission is granted
    else if (locationStatus.isGranted) {
        var serviceStatus = await Permission.location.serviceStatus;
        if (serviceStatus.isDisabled) {
            _showError('Location Service (GPS) must be ON for Bluetooth scanning.');
            return false;
        }
    }
    // If Location is denied but not permanently (locationStatus.isDenied),
    // we proceed, hoping the Nearby Devices permission is enough.
    // However, if scanning still fails, we will know Location is the problem.

    return true; // All critical checks passed
  }

  Future<void> _initiateConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = "Checking permissions..."; // Changed status message
    });

    // 1. Request Permissions at Runtime
    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      setState(() => _isConnecting = false);
      return;
    }

    setState(() {
      _connectionStatus = "Checking Bluetooth status...";
    });

    // 2. Check Adapter Status (Code remains correct as previously fixed)
    if (FlutterBluePlus.isSupported == false) {
      _showError('Bluetooth not supported on this device.');
      return;
    }

    // This is where the old error occurred. Should be fixed now.
    await FlutterBluePlus.turnOn();

    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;

    if (await FlutterBluePlus.isOn == false) {
      _showError('Bluetooth is turned off. Please enable it.');
      return;
    }

    // 3. Start Scanning
    setState(() {
      _connectionStatus = "Scanning for $LUMINO_DEVICE_NAME...";
    });

    // ... (rest of the scanning and connection logic remains the same) ...
    // ... (Use the original code from the previous response for the rest of _initiateConnection)

    await FlutterBluePlus.stopScan();

    var scan = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        if (result.device.platformName == LUMINO_DEVICE_NAME) {
          FlutterBluePlus.stopScan();
          await _connectToDevice(result.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    await Future.delayed(const Duration(seconds: 5));

    await scan.cancel();

    if (connectedLuminoDevice == null && mounted) {
      _showError('Device "$LUMINO_DEVICE_NAME" not found.');
    }

    setState(() {
      _isConnecting = false;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectionStatus = "Device found. Connecting...";
    });

    try {
      // Connect to the device with a timeout
      await device.connect(timeout: const Duration(seconds: 10));

      // Connection successful
      connectedLuminoDevice = device;

      setState(() {
        _connectionStatus = "Connected successfully!";
        _isConnecting = false;
      });

      // Navigate to the Control Page
      if (mounted) context.go('/control');

    } catch (e) {
      // Connection failed
      _showError('Connection failed: $e');
      connectedLuminoDevice = null;
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _connectionStatus = message;
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lumino Project'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "Welcome to the Lumino Project",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 40),
            if (_isConnecting)
              const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _connectionStatus,
              style: TextStyle(
                color: _connectionStatus.contains('Ready') || _connectionStatus.contains('Connected')
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isConnecting ? null : _initiateConnection, // Disable button while connecting
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: _isConnecting ? Colors.grey : Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _isConnecting ? "Connecting..." : "Initiate Connection",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Control Page (Second Page) ---
class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  // Mock data for the embedded system
  final LuminoControlData _data = LuminoControlData(
    currentDateTime: DateTime.now(),
    alarmDateTime: DateTime(2025, 1, 1, 7, 0),
    dimmingValue: 0.0,
  );

  BluetoothCharacteristic? _pwmCharacteristic;

  // Controller for the manual input field
  late final TextEditingController _valueController; // Renamed controller

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _discoverAndStoreCharacteristics() async {
    if (connectedLuminoDevice == null) return;

    // 1. Discover services
    List<BluetoothService> services = await connectedLuminoDevice!.discoverServices();

    // 2. Define the target UUIDs (using the constants defined earlier)
    Guid targetPwmCharGuid = Guid(LP_PWM_CHAR_UUID);
    Guid targetServiceGuid = Guid(LP_PWM_SERVICE_UUID);

    for (var service in services) {
      if (service.uuid == targetServiceGuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == targetPwmCharGuid) {
            // Store the characteristic reference
            _pwmCharacteristic = characteristic;
            print("Found and stored PWM characteristic: ${characteristic.uuid}");
          }
          // Add checks for other characteristics (e.g., time/alarm) here later
        }
      }
    }

    if (_pwmCharacteristic == null) {
      _showError("Critical Error: Could not find PWM characteristic.");
    }
  }

  @override
  void initState() {
    super.initState();

    if (connectedLuminoDevice != null) {
      _discoverAndStoreCharacteristics();
    }
    // Initialize the text field with the current slider value
    _valueController = TextEditingController(
      text: _data.dimmingValue.round().toString(),
    );
    // ... (rest of initState remains the same)
  }

  @override
  void dispose() {
    _valueController.dispose(); // Use new controller name
    super.dispose();
  }

  void _updateDimmingUI(double newValue) {
      setState(() {
        _data.dimmingValue = newValue; // Update the full range value
        // Update the text field to match the slider's rounded value
        _valueController.text = newValue.round().toString();
      });
  }

  // NEW: Function to handle the final slider release (sends BLE command)
  void _handleSliderValueChangeEnd(double finalValue) {
      // Send the raw value (0 to 10000) directly over BLE
      _sendDimmingValueToBLE(finalValue.round());
  }

  // Function to update the slider value and the text field
  void _updateDimmingValue(double newValue) {
    setState(() {
      _data.dimmingValue = newValue; // Update the full range value
      // Update the text field to match the slider's rounded value
      _valueController.text = newValue.round().toString();
    });
    // Send the raw value (0 to 10000) directly
    _sendDimmingValueToBLE(newValue.round());
  }

  // This function now sends the raw value directly, no multiplication needed.
  void _sendDimmingValueToBLE(int rawValue) async {
    if (_pwmCharacteristic == null) {
      _showError('Characteristic not ready. Try reconnecting.');
      return;
    }

    final ByteData byteData = ByteData(4);
    byteData.setUint32(0, rawValue, Endian.little);
    final List<int> valueBytes = byteData.buffer.asUint8List();

    try {
      await _pwmCharacteristic!.write(valueBytes, withoutResponse: false);

      // UI Feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BLE Write Success: Sent $rawValue (PWM value)')),
      );

    } catch (e) {
      _showError('BLE Write Failed: ${e.toString()}');
    }

    // Temporary UI feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Dimming value set to $rawValue (Raw PWM Value)')),
    );
  }

  // Helper functions (omitted for brevity, assume they are the same as before)
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectAlarmTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_data.alarmDateTime),
    );
    if (picked != null) {
      setState(() {
        _data.alarmDateTime = DateTime(
          _data.alarmDateTime.year,
          _data.alarmDateTime.month,
          _data.alarmDateTime.day,
          picked.hour,
          picked.minute,
        );
        // TODO: BLE command to set alarm time
        _sendDimmingValueToBLE(_data.dimmingValue.round());
      });
    }

    // --- START BLE WRITE CODE PLACEHOLDER ---
    // Example: If you had a characteristic named `dimmingCharacteristic`:
    /*
    try {
      final List<BluetoothService> services = await connectedLuminoDevice!.discoverServices();
      for (var service in services) {
        // Look for the service UUID for your device
        if (service.uuid.toString() == 'YOUR_SERVICE_UUID') {
          for (var characteristic in service.characteristics) {
            // Look for the characteristic UUID for dimming
            if (characteristic.uuid.toString() == 'YOUR_DIMMING_CHAR_UUID') {
              // Convert percentage to a byte (0-100)
              await characteristic.write([percentage], withoutResponse: true);
              print('Wrote percentage $percentage to characteristic.');
              return;
            }
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warning: Characteristic not found.')),
      );
    } catch (e) {
      print('BLE Write Error: $e');
    }
    */
    // --- END BLE WRITE CODE PLACEHOLDER ---

    // Temporary UI feedback
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text('Dimming value set to $percentage%. (BLE simulated)')),
    // );
  }

  void _handleDisconnection() {
    if (mounted) {
      connectedLuminoDevice = null;
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from Lumino device.')),
      );
    }
  }

  void _disconnect() async {
    try {
      // Disconnect the device
      await connectedLuminoDevice?.disconnect();
      // The listener will catch the state change and call _handleDisconnection
    } catch (e) {
      // Handle cases where disconnect fails gracefully
      _handleDisconnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lumino Control (${connectedLuminoDevice?.platformName ?? 'N/A'})'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ... (Current Time and Alarm Time Sections remain the same) ...

            // --- Current Date/Time Section ---
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blueGrey),
                title: const Text(
                  "Embedded System Time:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _formatDateTime(_data.currentDateTime),
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () {
                    // Simulate updating the embedded system's time to the phone's current time
                    setState(() {
                      _data.currentDateTime = DateTime.now();
                    });
                    // TODO: BLE command to update date/time
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Time updated on embedded system!')),
                    );
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Update'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Alarm Date/Time Section ---
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.alarm, color: Colors.orange),
                title: const Text(
                  "Alarm Time:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _formatTime(_data.alarmDateTime),
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: TextButton(
                  onPressed: () => _selectAlarmTime(context),
                  child: const Text('Edit'),
                ),
              ),
            ),
            const SizedBox(height: 30),

            const Divider(thickness: 1),
            const SizedBox(height: 30),

            // --- Dimming Control Section ---
            const Text(
              "Light Dimming Control",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: <Widget>[
                // 1. Horizontal Slider
                Expanded(
                  child: Slider(
                    value: _data.dimmingValue,
                    min: 0,
                    max: 10000,
                    divisions: 10000,
                    label: _data.dimmingValue.round().toString(),
                    onChanged: _updateDimmingUI,
                    onChangeEnd: _handleSliderValueChangeEnd,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.amber.shade100,
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Percentage Input Field
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      suffixText: 'PWM',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(10),
                    ),
                    onSubmitted: (value) {
                      int? v = int.tryParse(value);
                      if (v != null && v >= 0 && v <= 10000) {
                        _updateDimmingValue(v.toDouble());
                      } else {
                        _valueController.text = _data.dimmingValue.round().toString();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a value between 0 and 10000.')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // --- Disconnect Button ---
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
