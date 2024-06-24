import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

Future<String?> getIpAddress() async {
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4) {
        return addr.address;
      }
    }
  }
  return null;
}

void showTextToast(BuildContext ctx, String text) async {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(text),
  ));
}

num toDeg(double rad) {
  return (rad * 57.2958).toInt();
}

void showSettingsModalDialog(
    BuildContext context, int interval, Function setInterval) {
  int socketInterval = interval;

  void save() {
    if (socketInterval <= 0) {
      showTextToast(context, "Socket interval must be greater than 0ms");
      return;
    }
    setInterval(socketInterval);
    showTextToast(context, "Settings saved successfully!");
  }

  showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 350),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Settings",
                        style: Theme.of(context).textTheme.headlineSmall),
                    TextFormField(
                      initialValue: socketInterval.toString(),
                      decoration: const InputDecoration(
                          labelStyle: TextStyle(fontSize: 12),
                          labelText: "Socket interval (in ms)"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (value) {
                        socketInterval = int.parse(value);
                      },
                    ),
                    // TextFormField(
                    //   initialValue: '9600',
                    //   decoration: const InputDecoration(
                    //       labelStyle: TextStyle(fontSize: 12),
                    //       labelText: "Baud rate"),
                    //   keyboardType: TextInputType.number,
                    //   inputFormatters: <TextInputFormatter>[
                    //     FilteringTextInputFormatter.digitsOnly
                    //   ], // Only numbers can be entered
                    // ),
                    TextButton(
                        style: const ButtonStyle(
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(8.0)),
                          )),
                          backgroundColor: WidgetStatePropertyAll(Colors.green),
                          foregroundColor: WidgetStatePropertyAll(Colors.white),
                        ),
                        onPressed: save,
                        child: const Text(
                          "Save",
                        )),
                  ],
                ),
              ),
            ),
          ),
        );
      });
}
