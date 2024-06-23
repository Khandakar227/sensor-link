# Sensor Link

Sensor Link is a mobile application that turns your smartphone into a server, broadcasting IMU (Inertial Measurement Unit) sensor data over your local network at port 4040.

## Release APK
[/exports/release/app-release.apk](/exports/release/sensor_link.apk)

## Features

1. Creates a server within your smartphone
2. Broadcasts IMU sensor data (accelerometer, gyroscope, magnetometer, absolute rotation)
3. Supports data retrieval via HTTP requests or WebSocket connections
4. Can run in the foreground for continuous operation

## Usage

1. Launch the app.
2. The app will display the local IP address and port for connections.
3. Send a GET request to http://<phone-ip>:4040 to receive the latest sensor data. Or connect to the socket server through `ws://<phone-ip>:4040/ws`
the app will continously broadcast sensor data after every 100ms.

## Data Format
The sensor data is returned in JSON format:
```
{
  "accelerometer": {
    "x": 0.01,
    "y": -0.02,
    "z": 9.81
  },
  "gyroscope": {
    "x": 0.001,
    "y": 0.002,
    "z": -0.001
  },
  "magnetometer": {
    "x": 0.001,
    "y": 0.002,
    "z": -0.001
  },
  "rotation": {
    "x": 0.001,
    "y": 0.002,
    "z": -0.001
  }
}
```

## Notes
All 3 imu vector values are in radian. rotation vector value is returned in degree.

## Features to be added
1. Rotation values in radian.
2. Serial communication.
3. Socket transmission frequency modification.