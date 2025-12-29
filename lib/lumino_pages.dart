import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

// --- Configuration ---
const String LUMINO_DEVICE_NAME = "Lumino";
const String LP_PWM_SERVICE_UUID = "8e2a9190-7a6f-4e60-9fb9-2262a8d35112";
const String LP_PWM_CHAR_UUID = "8e2a9191-7a6f-4e60-9fb9-2262a8d35112";
const String LP_ALARM_TIME_CHAR_UUID = "8e2a9192-7a6f-4e60-9fb9-2262a8d35112";
const String LP_FREQ_CHAR_UUID = "8e2a9193-7a6f-4e60-9fb9-2262a8d35112";
const String LP_AUTOPWM_CHAR_UUID = "8e2a9194-7a6f-4e60-9fb9-2262a8d35112";
const String LP_TIME_SERVICE_UUID = "00001805-0000-1000-8000-00805f9b34fb";
const String LP_CURRENT_TIME_CHAR_UUID = "00002a2b-0000-1000-8000-00805f9b34fb";
const double LP_MAX_PWM_VALUE = 1000000;
BluetoothDevice? connectedLuminoDevice;

// --- State Class for the Control Page ---
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
    return true; // All critical checks passed
  }

  Future<void> _initiateConnection() async {
    if (mounted) {
      setState(() {
        _isConnecting = true;
        _connectionStatus = "Checking permissions..."; // Changed status message
      });
    }

    // 1. Request Permissions at Runtime
    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      if (mounted) setState(() => _isConnecting = false);
      return;
    }

    if (mounted) {
      setState(() {
        _connectionStatus = "Checking Bluetooth status...";
      });
    }

    // 2. Check Adapter Status (Code remains correct as previously fixed)
    if (FlutterBluePlus.isSupported == false) {
      _showError('Bluetooth not supported on this device.');
      return;
    }

    await FlutterBluePlus.turnOn();
    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;

    if (await FlutterBluePlus.isOn == false) {
      _showError('Bluetooth is turned off. Please enable it.');
      return;
    }

    // 3. Start Scanning
    if (mounted) {
      setState(() {
        _connectionStatus = "Scanning for $LUMINO_DEVICE_NAME...";
      });
    }

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

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectionStatus = "Device found. Connecting...";
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      connectedLuminoDevice = device;

      setState(() {
        _connectionStatus = "Connected successfully!";
        _isConnecting = false;
      });

      if (mounted) context.go('/control');

    } catch (e) {
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
        title: const Text('Lumino Control'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover, // Ensure the image covers the entire screen area
              opacity: const AlwaysStoppedAnimation(0.2), // Optional: Adjust opacity for better text readability
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(20.0),
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
        ],
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

  bool _isAlarmEnabled = false;
  // Map to track the state of each day (1=Monday, 7=Sunday)
  Map<int, bool> _alarmDays = {
      1: false, // Monday
      2: false, // Tuesday
      3: false, // Wednesday
      4: false, // Thursday
      5: false, // Friday
      6: false, // Saturday
      7: false, // Sunday
  };

  BluetoothCharacteristic? _pwmCharacteristic;
  BluetoothCharacteristic? _currentTimeCharacteristic;
  BluetoothCharacteristic? _alarmTimeCharacteristic;
  BluetoothCharacteristic? _autoPwmCharacteristic;

  // Controller for the manual input field
  late final TextEditingController _valueController; // Renamed controller
  int _durationSeconds = 60;
  late final TextEditingController _durationController = TextEditingController(text: 60.toString());

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
    Guid targetServiceGuid = Guid(LP_PWM_SERVICE_UUID);
    Guid targetPwmCharGuid = Guid(LP_PWM_CHAR_UUID);
    Guid targetAlarmTimeCharGuid = Guid(LP_ALARM_TIME_CHAR_UUID);
    Guid targetAutoPwmCharGuid = Guid(LP_AUTOPWM_CHAR_UUID);

    Guid targetTimeServiceGuid = Guid(LP_TIME_SERVICE_UUID);
    Guid targetCurrentTimeCharGuid = Guid(LP_CURRENT_TIME_CHAR_UUID);

    for (var service in services) {
      if (service.uuid == targetServiceGuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == targetPwmCharGuid) {
            // Store the characteristic reference
            _pwmCharacteristic = characteristic;
            print("Found and stored PWM characteristic: ${characteristic.uuid}");
          } else if (characteristic.uuid == targetAlarmTimeCharGuid) {
            _alarmTimeCharacteristic = characteristic;
            print("Found and stored Alarm characteristic: ${characteristic.uuid}");
          } else if (characteristic.uuid == targetAutoPwmCharGuid) {
            _autoPwmCharacteristic = characteristic;
            print("Found and stored AutoPWM characteristic: ${characteristic.uuid}");
          }
          // Add checks for other characteristics (e.g., time/alarm) here later
        }
      } else if (service.uuid == targetTimeServiceGuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == targetCurrentTimeCharGuid) {
            _currentTimeCharacteristic = characteristic;
            print("Found and stored current time characteristic: ${characteristic.uuid}");
          }
        }
      }
    }

    // Critical check for all characteristics
    if (_pwmCharacteristic == null || _currentTimeCharacteristic == null ||
        _alarmTimeCharacteristic == null || _autoPwmCharacteristic == null) {
      _showError("Critical Error: One or more characteristics (PWM/Time/Alarm) not found.");
    } else {
      // NEW: Trigger the read operation after successful discovery
      _readInitialData();
    }
  }

  static const int CTS_CURRENT_TIME_LENGTH = 10;
  static const int ALARM_CHAR_LENGTH = 4;

  Future<void> _readInitialData() async {
    if (_currentTimeCharacteristic == null || _alarmTimeCharacteristic == null) {
      _showError("Cannot read time data: Characteristics not set.");
      return;
    }

    // 1. Read Current Time (Using BLE CTS Format)
    try {
      List<int> currentTimeBytes = await _currentTimeCharacteristic!.read();

      // Ensure 10 bytes are received as per BLE CTS standard
      if (currentTimeBytes.length == CTS_CURRENT_TIME_LENGTH) {
        final ByteData byteData = ByteData.sublistView(Uint8List.fromList(currentTimeBytes));

        // Decode the 10-byte structure:

        // Bytes 0-1: Year (Little Endian)
        int year = byteData.getUint16(0, Endian.little);

        // Bytes 2-6: Month, Day, Hour, Minute, Second
        int month = byteData.getUint8(2);
        int day = byteData.getUint8(3);
        int hour = byteData.getUint8(4);
        int minute = byteData.getUint8(5);
        int second = byteData.getUint8(6);

        // Create Dart DateTime object (Day of Week, Fractions, Adjust Reason are ignored for DateTime creation)
        DateTime currentTime = DateTime(year, month, day, hour, minute, second);

        setState(() {
          _data.currentDateTime = currentTime;
        });
        print("Read Current Time (CTS): $currentTime");

      } else {
        _showError("Current Time characteristic returned ${currentTimeBytes.length} bytes (expected $CTS_CURRENT_TIME_LENGTH).");
      }

    } catch (e) {
      _showError("Failed to read Current Time: ${e.toString()}");
    }

    // 2. Read Alarm Data (Decoding 4-byte custom struct)
    try {
      List<int> alarmTimeBytes = await _alarmTimeCharacteristic!.read();

      if (alarmTimeBytes.length == ALARM_CHAR_LENGTH) {
        final ByteData byteData = ByteData.sublistView(Uint8List.fromList(alarmTimeBytes));

        // Decode the 4 bytes:
        int isEnabled = byteData.getUint8(0);
        int hour = byteData.getUint8(1);
        int minute = byteData.getUint8(2);
        int dayOfWeekBitset = byteData.getUint8(3);

        // Update the alarm time in _data (only for display)
        DateTime readTime = DateTime(2000, 1, 1, hour, minute);

        setState(() {
          _data.alarmDateTime = readTime;
          _isAlarmEnabled = isEnabled == 1;

          // Decode the day of week bitset (Byte 3)
          // Zephyr: MONDAY is BIT(0), TUESDAY is BIT(1), etc.
          // Flutter: 1=Mon, 2=Tue, ..., 7=Sun
          for (int i = 0; i < 7; i++) {
              // Check if the i-th bit is set
              bool isSet = (dayOfWeekBitset & (1 << i)) != 0;
              // Map bit index (0-6) to day index (1-7)
              _alarmDays[i + 1] = isSet;
          }
        });
        print("Read Alarm: Hour $hour, Minute $minute, Enabled $_isAlarmEnabled, Days $dayOfWeekBitset");

      } else {
        _showError("Alarm characteristic returned ${alarmTimeBytes.length} bytes (expected 4).");
      }

    } catch (e) {
      _showError("Failed to read Alarm: ${e.toString()}");
    }
  }

  Future<void> _writeCurrentTimeToBLE() async {
    if (_currentTimeCharacteristic == null) {
        _showError('Current Time characteristic not ready.');
        return;
    }

    final DateTime now = DateTime.now();

    // 1. Prepare the 10-byte data structure
    final ByteData byteData = ByteData(CTS_CURRENT_TIME_LENGTH);

    // Byte 0-1: Year (uint16_t, Little Endian)
    // The C code uses sys_cpu_to_le16, so we must use Endian.little
    byteData.setUint16(0, now.year, Endian.little);

    // Byte 2: Month (uint8_t, 1=Jan)
    byteData.setUint8(2, now.month);

    // Byte 3: Day of Month (uint8_t)
    byteData.setUint8(3, now.day);

    // Byte 4: Hour (uint8_t)
    byteData.setUint8(4, now.hour);

    // Byte 5: Minute (uint8_t)
    byteData.setUint8(5, now.minute);

    // Byte 6: Second (uint8_t)
    byteData.setUint8(6, now.second);

    // Byte 7: Day of Week (uint8_t, 1=Mon, 7=Sun). Dart's weekday starts at 1=Mon.
    byteData.setUint8(7, now.weekday);

    // Byte 8: Fractions 256 (uint8_t, often 0)
    byteData.setUint8(8, 0);

    // Byte 9: Adjust Reason (uint8_t, 0=No update, as per your C code)
    byteData.setUint8(9, 0);

    final List<int> valueBytes = byteData.buffer.asUint8List();

    // 2. Write the data
    try {
        // Use withoutResponse: false (standard write)
        await _currentTimeCharacteristic!.write(valueBytes, withoutResponse: false);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('System time synchronized to: ${now.toIso8601String()}')),
        );

        // After writing, re-read the device time to confirm synchronization
        _readInitialData();

    } catch (e) {
        _showError('Current Time Write Failed: ${e.toString()}');
    }
  }

  Future<void> _writeAlarmToBLE() async {
    if (_alarmTimeCharacteristic == null) {
        _showError('Alarm characteristic not ready.');
        return;
    }

    // 1. Encode Day of Week Bitset (Byte 3)
    int dayOfWeekBitset = 0;
    // Iterate from Monday (index 1) to Sunday (index 7)
    for (int i = 1; i <= 7; i++) {
        if (_alarmDays[i] == true) {
            // Set the corresponding bit (i-1 is the bit index: 0 for Mon, 6 for Sun)
            dayOfWeekBitset |= (1 << (i - 1));
        }
    }

    // 2. Prepare the 4-byte data structure
    final ByteData byteData = ByteData(ALARM_CHAR_LENGTH);

    // Byte 0: is_enabled (1 or 0)
    byteData.setUint8(0, _isAlarmEnabled ? 1 : 0);

    // Byte 1: hour
    byteData.setUint8(1, _data.alarmDateTime.hour);

    // Byte 2: minute
    byteData.setUint8(2, _data.alarmDateTime.minute);

    // Byte 3: day_of_week bitset
    byteData.setUint8(3, dayOfWeekBitset);

    final List<int> valueBytes = byteData.buffer.asUint8List();

    // 3. Write the data
    try {
        await _alarmTimeCharacteristic!.write(valueBytes, withoutResponse: false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alarm updated successfully!')),
        );
    } catch (e) {
        _showError('Alarm Write Failed: ${e.toString()}');
    }
  }

  // command: 1 for start, 0 for stop
  Future<void> _sendAutoPwmCommand(int command) async {
    if (_autoPwmCharacteristic == null) {
        _showError('AutoPWM characteristic not ready.');
        return;
    }

    final ByteData byteData = ByteData(5);

    // Byte 0: Command (0 or 1)
    byteData.setUint8(0, command);

    // Bytes 1-4: Duration in seconds (uint32_t, Little Endian)
    byteData.setUint32(1, command == 1 ? _durationSeconds : 0, Endian.little);

    final List<int> valueBytes = byteData.buffer.asUint8List();

    try {
        await _autoPwmCharacteristic!.write(valueBytes, withoutResponse: false);

        String message = (command == 1)
            ? 'Wake-up sequence started for $_durationSeconds seconds.'
            : 'Wake-up sequence stopped.';

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
        );

    } catch (e) {
        _showError('AutoPWM Command Failed: ${e.toString()}');
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

    _durationController.addListener(_updateDurationFromField);
  }

  @override
  void dispose() {
    _valueController.dispose(); // Use new controller name
    _durationController.dispose();
    super.dispose();
  }

  void _updateDurationFromField() {
      final text = _durationController.text;
      final int? newDuration = int.tryParse(text);
      if (newDuration != null && newDuration >= 0) {
        // Since this listener runs constantly, we use setState to ensure the UI
        // reflects the duration (though it doesn't change anything visually outside the TextField)
        setState(() {
            _durationSeconds = newDuration;
        });
    }
  }

  void _updateDimmingUI(double newValue) {
      setState(() {
        _data.dimmingValue = newValue; // Update the full range value
        // Update the text field to match the slider's rounded value
        _valueController.text = newValue.round().toString();
      });
  }

  void _handleCoarseSliderChange(double newValue) {
      _updateDimmingUI(newValue);
  }

  void _handleFineSliderChange(double newValue) {
      if (_data.dimmingValue <= 10000) {
          double commandValue = newValue.clamp(0, 10000);
          _updateDimmingUI(commandValue);
      }
  }

  void _handleSliderValueChangeEnd(double finalValue) {
      _sendDimmingValueToBLE(finalValue.round());
  }

  // Function to update the slider value and the text field
  void _updateDimmingValue(double newValue) {
    setState(() {
      _data.dimmingValue = newValue; // Update the full range value
      // Update the text field to match the slider's rounded value
      _valueController.text = newValue.round().toString();
    });
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

  void _handlePwmButtonPress(int adjustment) {
    double currentValue = _data.dimmingValue;
    double newValue = currentValue + adjustment;

    if (newValue < 0) {
        newValue = 0;
    } else if (newValue > LP_MAX_PWM_VALUE) {
        newValue = LP_MAX_PWM_VALUE;
    }

    // Apply the update if we are in the active control range (0-100)
    // OR if we are adjusting downward from just above 100 (101 -> 100)
    if (currentValue <= 10000 || newValue <= 10000) {
        _updateDimmingUI(newValue);
        _handleSliderValueChangeEnd(newValue);
    }
  }

  // Helper functions (omitted for brevity, assume they are the same as before)
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectAlarmTime(TimeOfDay selectedTime) async {
    // 1. Create a new DateTime object using the selected time
    // We only care about hour and minute for the alarm characteristic
    DateTime newAlarmDateTime = DateTime(
        _data.alarmDateTime.year,
        _data.alarmDateTime.month,
        _data.alarmDateTime.day,
        selectedTime.hour,
        selectedTime.minute,
    );

    // 2. Update the state
    setState(() {
      _data.alarmDateTime = newAlarmDateTime;
    });
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
    // 1. Check if the device object is available
    if (connectedLuminoDevice != null) {
        try {
            // 2. Send the explicit disconnect command to the BLE stack
            await connectedLuminoDevice!.disconnect();

            // NOTE: The connectionState listener often catches the disconnect,
            // but we call _handleDisconnection manually as a fallback for the button press.
            _handleDisconnection();

        } catch (e) {
            // If the disconnect fails (e.g., device already powered off),
            // we still treat it as disconnected and clean up.
            _handleDisconnection();
        }
    } else {
        // If connectedLuminoDevice is null, just handle cleanup and navigation
        _handleDisconnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lumino Control'),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 2.0,

        actions: <Widget>[
          IconButton(
            // Use the exit icon to visually represent disconnection
            icon: const Icon(
              Icons.exit_to_app,
              color: Colors.red, // Make it red for high visibility/warning
            ),
            onPressed: _disconnect, // Call your existing disconnect function
            tooltip: 'Disconnect', // Good practice for accessibility
          ),
          const SizedBox(width: 8), // Optional: small padding on the right edge
        ],
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
                  onPressed: _writeCurrentTimeToBLE,
                  icon: const Icon(Icons.sync),
                  label: const Text('Update'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- ALARM CONTROL SECTION ---
            Text(
                "Alarm Control",
                style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),

            // Alarm Enable Switch and Time Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Enable Switch
                Row(
                    children: [
                        const Text('Alarm Enabled:'),
                        Switch(
                            value: _isAlarmEnabled,
                            onChanged: (bool value) {
                                setState(() {
                                    _isAlarmEnabled = value;
                                });
                                _writeAlarmToBLE(); // Write immediately on switch change
                            },
                        ),
                    ],
                ),

                // 2. Time Picker Button (Uses existing logic)
                TextButton(
                  onPressed: () async {
                    TimeOfDay? selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_data.alarmDateTime),
                    );
                    if (selectedTime != null) {
                      _selectAlarmTime(selectedTime); // Calls the existing _selectAlarmTime function
                      _writeAlarmToBLE(); // Write immediately after time change
                    }
                  },
                  child: Text(
                    _formatTime(_data.alarmDateTime),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 3. Day of Week Bitset Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Repeat Days:'),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final dayIndex = index + 1; // 1=Mon, 7=Sun
                    final dayNames = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _alarmDays[dayIndex] = !(_alarmDays[dayIndex] ?? false);
                        });
                        _writeAlarmToBLE(); // Write immediately on day toggle
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_alarmDays[dayIndex] ?? false) ? Colors.blue : Colors.grey.shade300,
                        ),
                        child: Text(
                          dayNames[index],
                          style: TextStyle(
                            color: (_alarmDays[dayIndex] ?? false) ? Colors.white : Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),

            const Divider(),
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
                const SizedBox(width: 50, child: Text("Main", style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    value: _data.dimmingValue,
                    min: 0,
                    max: LP_MAX_PWM_VALUE,
                    divisions: 10000,
                    label: _data.dimmingValue.round().toString(),
                    onChanged: _handleCoarseSliderChange,
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
                      if (v != null && v >= 0 && v <= LP_MAX_PWM_VALUE) {
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
            const SizedBox(height: 10),

            // --- 2. FINE SLIDER ROW (Focus 0 - 10000) ---
            Row(
              children: <Widget>[
                const SizedBox(width: 50, child: Text("Fine", style: TextStyle(fontSize: 12))),
                Expanded(
                  child: Slider(
                    // Visual Value: Caps at 100 for display
                    value: _data.dimmingValue.clamp(0, 10000),
                    min: 0,
                    max: 10000, // Range is always 0 to 10000
                    divisions: 100, // 100 unit per division
                    label: _data.dimmingValue.round().toString(),
                    onChanged: _handleFineSliderChange, // Only allows input if total value is <= 100
                    onChangeEnd: _handleSliderValueChangeEnd, // Sends the final command
                    activeColor: Colors.green,
                    inactiveColor: Colors.green.shade100,
                  ),
                ),
                const SizedBox(width: 100 + 10), // Offset to align with the text field column
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Minus 1 Button
                ElevatedButton.icon(
                  onPressed: () => _handlePwmButtonPress(-100),
                  icon: const Icon(Icons.remove),
                  label: const Text("100"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: Colors.blueGrey.shade100,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 50),

                // Plus 1 Button
                ElevatedButton.icon(
                  onPressed: () => _handlePwmButtonPress(100),
                  icon: const Icon(Icons.add),
                  label: const Text("100"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: Colors.blueGrey.shade100,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Start/Stop Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. START Button
                ElevatedButton.icon(
                  onPressed: () => _sendAutoPwmCommand(1), // Command 1: Start
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text("Start"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(width: 15),
                // const SizedBox(width: 15),

                // 3. STOP Button
                ElevatedButton.icon(
                  onPressed: () => _sendAutoPwmCommand(0), // Command 0: Stop
                  icon: const Icon(Icons.stop, size: 20),
                  label: const Text("Stop"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
