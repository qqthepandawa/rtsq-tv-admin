/// Konfigurasi Supabase untuk panel admin.
///
/// Hanya kunci *publishable* yang boleh ada di repo/aplikasi. Jangan pernah
/// menambahkan `service_role` di sini. Keamanan dijaga oleh RLS.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://qrjamxhbfnemfinqbhfh.supabase.co';

  static const String publishableKey =
      'sb_publishable_KaMGXIAHHPjWMG5vA0Q64g_miBf1nuA';

  /// Basis URL panel ini. Dipakai untuk tautan konfirmasi email/reset sandi.
  static const String adminBaseUrl = 'https://tv.rtsq.id';

  static const String storageBucket = 'tv-media';
}
