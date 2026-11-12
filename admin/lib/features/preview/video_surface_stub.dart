import 'package:flutter/material.dart';

/// Fallback non-web: tidak ada pemutar video di platform ini.
Widget buildVideoSurface({required String url}) {
  return const ColoredBox(
    color: Color(0xFF0A1512),
    child: Center(
      child: Icon(Icons.videocam_rounded, size: 96, color: Color(0x9931E0C2)),
    ),
  );
}
