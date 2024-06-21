import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

enum TaskEvent { repeatEvent }

class ForegroundTaskHandler extends TaskHandler {
  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    print("on repeat event");
    sendPort?.send(TaskEvent.repeatEvent);
  }

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    print("on start event");
    sendPort?.send(TaskEvent.repeatEvent);
  }
}
