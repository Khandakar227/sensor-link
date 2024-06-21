import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:sensorlink/services/foreground_service.dart';
import 'package:sensorlink/utils.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:motion_sensors/motion_sensors.dart' as motion_sensors;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'components/imu_card.dart';
import 'models/SensorData.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Link',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green[800] ?? Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Sensor Link'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HttpServer? server;
  bool _isServerRunning = false;
  String? _ipAddress;
  IMUData? _accelerometerData, _gyroscopeData, _magnetometerData, _rotationData;
  ReceivePort? _receivePort;

  final Connectivity _connectivity = Connectivity();
  late Stream<List<ConnectivityResult>> _connectivityStream;
  final List<WebSocket> _clients = [];
  final StreamController<String> _dataStreamController =
      StreamController<String>();

  final accelerometerEvent = accelerometerEventStream();
  final gyroscopeEvent = gyroscopeEventStream();
  final magnetometerEvent = magnetometerEventStream();

  @override
  void initState() {
    super.initState();
    _startWebSocketServer();

    _connectivityStream = _connectivity.onConnectivityChanged;

    _connectivityStream.listen((event) {
      _updateIpAddress();
    });
    _updateIpAddress();

    accelerometerEvent.listen(onAcceleroMeterData);
    gyroscopeEvent.listen(onGyroscopeData);
    magnetometerEvent.listen(onMagnetometerData);

    motion_sensors.motionSensors.absoluteOrientation
        .listen(onAbsoluteOrientationData);

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _broadcastSensorData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissionForAndroid();
      _initForegroundTask();

      // the previous ReceivePort without restarting the service.
      if (await FlutterForegroundTask.isRunningService) {
        final newReceivePort = FlutterForegroundTask.receivePort;
        _registerReceivePort(newReceivePort);
      }
      _startForegroundTask();
    });
  }

  @override
  void dispose() {
    _stopWebSocketServer();
    _dataStreamController.close();
    _closeReceivePort();
    _stopForegroundTask();
    super.dispose();
  }

  Future<void> _requestPermissionForAndroid() async {
    if (!Platform.isAndroid) {
      return;
    }
    logger.i('Requesting permission for Android...');
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      logger.i('Requesting ignore battery optimization permission');
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Android 13 and higher, need to allow notification permission to expose foreground service notification.
    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      logger.i('Requesting notification permission for Android 13 and higher');
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _initForegroundTask() {
    logger.t('Initializing Foreground Task...');
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Sensor Link Foreground Service',
        channelDescription:
            'Senspr reading is the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
          backgroundColor: Colors.green,
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    logger.i('Foreground Task initialized');
  }

  Future<bool> _startForegroundTask() async {
    // Register the receivePort before starting the service.
    final ReceivePort? receivePort = FlutterForegroundTask.receivePort;
    final bool isRegistered = _registerReceivePort(receivePort);
    logger.i('ReceivePort isRegistered: $isRegistered');
    if (!isRegistered) {
      logger.e('Failed to register receivePort!');
      return false;
    }
    logger.i('Registered, Starting Foreground Task...');
    if (await FlutterForegroundTask.isRunningService) {
      logger.i('Restarting Foreground Task...');
      return FlutterForegroundTask.restartService();
    } else {
      logger.i('Starting Foreground Task...');
      return FlutterForegroundTask.startService(
        notificationTitle: 'Sensor Link is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  }

  Future<bool> _stopForegroundTask() {
    return FlutterForegroundTask.stopService();
  }

  bool _registerReceivePort(ReceivePort? newReceivePort) {
    logger.i('Registering ReceivePort...');
    if (newReceivePort == null) {
      logger.i('ReceivePort is null');
      return false;
    }
    _closeReceivePort();
    _receivePort = newReceivePort;
    _receivePort?.listen((data) {
      logger.i('Received data: $data');
      if (data is TaskEvent) {
        switch (data) {
          case TaskEvent.repeatEvent:
            accelerometerEvent.listen(onAcceleroMeterData);
            gyroscopeEvent.listen(onGyroscopeData);
            magnetometerEvent.listen(onMagnetometerData);
            break;
        }
      }
    });

    return _receivePort != null;
  }

  void _closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }

  void _startWebSocketServer() async {
    server = await HttpServer.bind(InternetAddress.anyIPv4, 4040);
    logger.d(
        'WebSocket server is running on ws://${server!.address.address}:${server!.port}');
    showTextToast(context, 'Server started');
    setState(() {
      _isServerRunning = true;
    });

    server!.listen((HttpRequest request) async {
      if (request.uri.path == '/ws') {
        var socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocket(socket);
      } else if (request.method == 'GET' && request.uri.path == '/') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonifyData())
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    });
  }

  void _handleWebSocket(WebSocket socket) {
    _clients.add(socket);
    logger.d('Client connected');

    _dataStreamController.stream.listen((data) {
      if (socket.readyState == WebSocket.open) {
        socket.add(data);
      }
    });
    socket.done.then((_) {
      _clients.remove(socket);
      logger.d('Client disconnected');
    });
  }

  String jsonifyData() {
    return jsonEncode({
      'accelerometer': _accelerometerData?.toJson(),
      'gyroscope': _gyroscopeData?.toJson(),
      'magnetometer': _magnetometerData?.toJson(),
      'rotation': _rotationData?.toJson(),
    });
  }

  void _broadcastSensorData() {
    _dataStreamController.add(jsonifyData());
  }

  void _stopWebSocketServer() {
    for (var client in _clients) {
      client.close();
    }
    server!.close();
    logger.d('Server stopped');
    showTextToast(context, 'Server stopped');
    setState(() {
      _isServerRunning = false;
    });
  }

  Future<void> _updateIpAddress() async {
    String? ipAddress;
    try {
      logger.d('Getting IP address...');
      ipAddress = await getIpAddress();
    } catch (e) {
      logger.e('Failed to get IP address: $e');
      showTextToast(context, 'Failed to get IP address: $e}');
    }
    setState(() {
      _ipAddress = ipAddress;
    });
  }

  onAcceleroMeterData(AccelerometerEvent event) {
    setState(() {
      _accelerometerData = IMUData(
        x: event.x,
        y: event.y,
        z: event.z,
      );
    });
  }

  onGyroscopeData(GyroscopeEvent event) {
    setState(() {
      _gyroscopeData = IMUData(
        x: event.x,
        y: event.y,
        z: event.z,
      );
    });
  }

  onMagnetometerData(MagnetometerEvent event) {
    setState(() {
      _magnetometerData = IMUData(
        x: event.x,
        y: event.y,
        z: event.z,
      );
    });
  }

  onAbsoluteOrientationData(motion_sensors.AbsoluteOrientationEvent event) {
    setState(() {
      _rotationData = IMUData(
        x: toDeg(event.pitch),
        y: toDeg(event.yaw),
        z: toDeg(event.roll),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Text(
                    _isServerRunning
                        ? 'Server Started at $_ipAddress:${server!.port}'
                        : 'Server is not running',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ImuCard(
                    sensorName: 'Accelerometer',
                    x: _accelerometerData?.x ?? 0,
                    y: _accelerometerData?.y ?? 0,
                    z: _accelerometerData?.z ?? 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ImuCard(
                    sensorName: 'Gyroscope',
                    x: _gyroscopeData?.x ?? 0,
                    y: _gyroscopeData?.y ?? 0,
                    z: _gyroscopeData?.z ?? 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ImuCard(
                    sensorName: 'Magnetometer',
                    x: _magnetometerData?.x ?? 0,
                    y: _magnetometerData?.y ?? 0,
                    z: _magnetometerData?.z ?? 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: ImuCard(
                    sensorName: 'Rotation',
                    x: _rotationData?.x ?? 0,
                    y: _rotationData?.y ?? 0,
                    z: _rotationData?.z ?? 0,
                    sufffix: '°',
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
