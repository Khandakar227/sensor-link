import 'dart:io';

import 'package:flutter/material.dart';

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
