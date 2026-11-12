// Permukaan pemutar video untuk pratinjau TV.
//
// Di web memakai elemen `<video>` asli (bisa diputar, ada kontrol), sedangkan
// di platform lain (mis. saat `flutter test`) memakai kotak statis.
export 'video_surface_stub.dart'
    if (dart.library.js_interop) 'video_surface_web.dart';
