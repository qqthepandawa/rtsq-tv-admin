import 'dart:js_interop';
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
      final wrapper =
          web.document.createElement('div') as web.HTMLDivElement;
      wrapper.style
        ..setProperty('position', 'relative')
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('background-color', '#050908');

      final video =
          web.document.createElement('video') as web.HTMLVideoElement;
      video
        ..src = url
        ..controls = true
        ..muted = true
        ..autoplay = true
        ..preload = 'auto'
        ..setAttribute('playsinline', 'true');
      video.style
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('object-fit', 'contain')
        ..setProperty('background-color', '#050908')
        ..setProperty('display', 'block');

      // Pesan bila browser tidak bisa men-decode video (mis. H.265/HEVC).
      final warning = web.document.createElement('div') as web.HTMLDivElement;
      warning.style
        ..setProperty('position', 'absolute')
        ..setProperty('inset', '0')
        ..setProperty('display', 'none')
        ..setProperty('align-items', 'center')
        ..setProperty('justify-content', 'center')
        ..setProperty('padding', '24px')
        ..setProperty('text-align', 'center')
        ..setProperty('color', '#F3FBF7')
        ..setProperty('background-color', 'rgba(5, 9, 8, 0.92)')
        ..setProperty('font-family', 'PlusJakartaSans, system-ui, sans-serif')
        ..setProperty('font-size', '16px')
        ..setProperty('line-height', '1.6');
      warning.textContent =
          'Video belum bisa ditampilkan di browser ini. Coba tekan tombol '
          'putar pada kontrol. Jika tetap hitam, berkasnya mungkin '
          'H.265/HEVC atau MOV — ekspor ulang sebagai MP4 H.264. TV tetap '
          'bisa memutar berkas aslinya.';

      var started = false;

      video.addEventListener(
        'playing',
        ((web.Event _) {
          started = true;
          warning.style.setProperty('display', 'none');
        }).toJS,
      );
      video.addEventListener(
        'error',
        ((web.Event _) {
          warning.style.setProperty('display', 'flex');
        }).toJS,
      );
      // Bila setelah 8 detik belum ada frame yang tampil (readyState < 2),
      // browser hampir pasti tidak bisa menampilkan berkasnya.
      web.window.setTimeout(
        (() {
          if (started || video.readyState >= 2) return;
          warning.style.setProperty('display', 'flex');
        }).toJS,
        8000.toJS,
      );

      wrapper.append(video);
      wrapper.append(warning);
      return wrapper;
    });
    return type;
  });
  return HtmlElementView(viewType: viewType);
}
