import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Pemutar `<video>` asli untuk pratinjau TV di web.
///
/// Satu tipe view didaftarkan per URL agar elemen video tidak dibuat ulang
/// setiap kali widget di-rebuild (mis. saat ticker berdetak).
final Map<String, String> _viewTypes = <String, String>{};
int _nextViewId = 0;

Widget buildVideoSurface({required String url}) {
  final viewType = _viewTypes.putIfAbsent(url, () {
    final type = 'rtsq-video-preview-${_nextViewId++}';
    ui_web.platformViewRegistry.registerViewFactory(type, (int viewId) {
      final video =
          web.document.createElement('video') as web.HTMLVideoElement;
      video
        ..src = url
        ..controls = true
        ..muted = true
        ..preload = 'auto'
        ..setAttribute('playsinline', 'true');
      video.style
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('object-fit', 'contain')
        ..setProperty('background-color', '#050908')
        ..setProperty('display', 'block');
      return video;
    });
    return type;
  });
  return HtmlElementView(viewType: viewType);
}
