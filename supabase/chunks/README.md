# Migrasi terpecah (fallback)

Gunakan folder ini **hanya jika** menempel `apply_all.sql` masih terpotong.
Setiap berkas di bawah 175 baris agar aman dari batas paste editor.

Jalankan **berurutan** di SQL Editor Supabase, satu berkas per **Run**:

| Berkas | Isi utama |
|---|---|
| `01.sql` | ekstensi; enum; tabel `profiles`, `admin_invites`, `contents`, `ticker`, `settings` |
| `02.sql` | tabel `devices`, `commands`, `logs`, `audit_log`; fungsi & trigger `touch_*` |
| `03.sql` | trigger `ticker_touch`; fungsi & trigger `audit_row`; helper RLS |
| `04.sql` | RPC `register_device` |
| `05.sql` | RPC `pair_device`, `device_heartbeat`, `claim_commands` |
| `06.sql` | RPC `complete_command`, `accept_invite`, `set_admin_active` |
| `07.sql` | RPC `purge_old_logs`, grant; RLS `profiles` + `admin_invites` |
| `08.sql` | RLS `settings`, `contents`, `ticker`, `devices`, `commands` |
| `09.sql` | RLS `logs` + `audit_log`; storage `tv-media`; realtime; seed `settings` |
| `10.sql` | seed `ticker` |

Semua pernyataan idempoten. Jika ada bagian yang gagal, perbaiki penyebabnya
lalu jalankan ulang bagian tersebut; bagian berikutnya boleh dilanjutkan.
