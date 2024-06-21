class IMUData {
  num x;
  num y;
  num z;

  IMUData({required this.x, required this.y, required this.z});

  factory IMUData.fromJson(Map<String, dynamic> json) {
    return IMUData(
      x: json['x'],
      y: json['y'],
      z: json['z'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
    };
  }
}
