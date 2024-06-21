import 'package:flutter/material.dart';

class ImuCard extends StatelessWidget {
  final String sensorName;
  final num x;
  final num y;
  final num z;
  final String? sufffix;

  const ImuCard({
    super.key,
    required this.sensorName,
    required this.x,
    required this.y,
    required this.z,
    this.sufffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sensorName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text('X:  $x ${sufffix ?? ''}'),
                Text('Y:  $y ${sufffix ?? ''}'),
                Text('Z:  $z ${sufffix ?? ''}'),
              ],
            ),
          ),
        ));
  }
}
