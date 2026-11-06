import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/session.dart';
import '../../app/widgets.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import '../preview/prayer_preview.dart';

const _prayerKeys = <String>['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya'];
const _prayerLabels = <String>['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.session});

  final AdminSession session;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repo = AdminRepository();
  final _formKey = GlobalKey<FormState>();

  final _orgName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _khutbah = TextEditingController();
  final _prayerDuration = TextEditingController();
  final _slideDuration = TextEditingController();
  final _tickerSpeed = TextEditingController();
  final _hijriOffset = TextEditingController();

  final _ihtiyati = <String, TextEditingController>{};
  final _iqamah = <String, TextEditingController>{};
  final _prayerMode = <String, bool>{};

  final _emergencyTitle = TextEditingController();
  final _emergencyBody = TextEditingController();
  bool _emergencyActive = false;
  String _emergencyColor = 'danger';
  DateTime? _emergencyUntil;

  SettingsRow _loaded = const SettingsRow();
  List<PreviewPrayer> _prayers = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  bool get _canEdit => widget.session.isSuper;

  @override
  void initState() {
    super.initState();
    for (final key in _prayerKeys) {
      _ihtiyati[key] = TextEditingController();
      _iqamah[key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _orgName,
      _address,
      _city,
      _latitude,
      _longitude,
      _khutbah,
      _prayerDuration,
      _slideDuration,
      _tickerSpeed,
      _hijriOffset,
      _emergencyTitle,
      _emergencyBody,
      ..._ihtiyati.values,
      ..._iqamah.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await _repo.fetchSettings();
      final prayers = await PrayerPreviewService.load(
        settings,
        Wib.toWib(Wib.now()),
      );
      if (!mounted) return;
      _apply(settings);
      setState(() {
        _loaded = settings;
        _prayers = prayers;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorText(error);
        _loading = false;
      });
    }
  }

  void _apply(SettingsRow settings) {
    _orgName.text = settings.orgName;
    _address.text = settings.address;
    _city.text = settings.city;
    _latitude.text = settings.latitude.toString();
    _longitude.text = settings.longitude.toString();
    _khutbah.text = settings.khutbahMinutes.toString();
    _prayerDuration.text = settings.prayerDurationMinutes.toString();
    _slideDuration.text = settings.slideDurationSeconds.toString();
    _tickerSpeed.text = settings.tickerSpeed.toString();
    _hijriOffset.text =
        (settings.hijriOffset['default'] as num?)?.toInt().toString() ?? '0';
    for (final key in _prayerKeys) {
      _ihtiyati[key]!.text =
          (settings.ihtiyati[key] as num?)?.toInt().toString() ?? '0';
      _iqamah[key]!.text =
          (settings.iqamahMinutes[key] as num?)?.toInt().toString() ?? '0';
      _prayerMode[key] = settings.prayerModeEnabled[key] as bool? ?? true;
    }
    final emergency = settings.emergency;
    _emergencyActive = emergency?['active'] as bool? ?? false;
    _emergencyTitle.text = emergency?['title'] as String? ?? '';
    _emergencyBody.text = emergency?['body'] as String? ?? '';
    _emergencyColor = emergency?['color'] as String? ?? 'danger';
    _emergencyUntil = Wib.parse(emergency?['until']);
  }

  SettingsRow _buildSettings() {
    return SettingsRow(
      orgName: _orgName.text,
      address: _address.text,
      city: _city.text,
      latitude: double.tryParse(_latitude.text.replaceAll(',', '.')) ?? 1.13,
      longitude:
          double.tryParse(_longitude.text.replaceAll(',', '.')) ?? 104.05,
      timezone: 'Asia/Jakarta',
      hijriOffset: {'default': int.tryParse(_hijriOffset.text) ?? 0},
      ihtiyati: {
        for (final key in _prayerKeys)
          key: int.tryParse(_ihtiyati[key]!.text) ?? 0,
      },
      iqamahMinutes: {
        for (final key in _prayerKeys)
          key: int.tryParse(_iqamah[key]!.text) ?? 0,
      },
      khutbahMinutes: int.tryParse(_khutbah.text) ?? 15,
      prayerDurationMinutes: int.tryParse(_prayerDuration.text) ?? 12,
      slideDurationSeconds: int.tryParse(_slideDuration.text) ?? 10,
      tickerSpeed: int.tryParse(_tickerSpeed.text) ?? 72,
      prayerModeEnabled: {
        for (final key in _prayerKeys) key: _prayerMode[key] ?? true,
      },
      emergency: {
        'active': _emergencyActive,
        'title': _emergencyTitle.text.trim(),
        'body': _emergencyBody.text.trim(),
        'color': _emergencyColor,
        'until': _emergencyUntil?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final settings = _buildSettings();
      await _repo.saveSettings(settings);
      final prayers = await PrayerPreviewService.load(
        settings,
        Wib.toWib(Wib.now()),
      );
      if (!mounted) return;
      setState(() {
        _loaded = settings;
        _prayers = prayers;
        _notice = 'Pengaturan disimpan. TV memuatnya dalam ±60 detik.';
      });
      showSnack(context, 'Pengaturan disimpan.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickEmergencyUntil() async {
    final initial = _emergencyUntil == null
        ? Wib.toWib(Wib.now()).add(const Duration(hours: 1))
        : Wib.toWib(_emergencyUntil!);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _emergencyUntil = Wib.fromWib(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Pengaturan',
        child: LoadingBlock(message: 'Memuat pengaturan…'),
      );
    }

    return PageScaffold(
      title: 'Pengaturan',
      subtitle: widget.session.isSuper
          ? 'Hanya admin utama yang dapat mengubah pengaturan tampilan dan '
                'jadwal.'
          : 'Anda masuk sebagai editor. Pengaturan hanya dapat dilihat; '
                'hubungi admin utama untuk mengubah.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat ulang'),
        ),
        ElevatedButton.icon(
          onPressed: _saving || !_canEdit ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_saving ? 'Menyimpan…' : 'Simpan perubahan'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) InlineError(message: _error!),
            if (_notice != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _notice!,
                  style: AdminText.body.copyWith(color: AdminColors.success),
                ),
              ),
            if (!_canEdit)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.goldSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Mode baca saja. Perubahan hanya dapat disimpan oleh admin '
                  'utama.',
                  style: AdminText.body.copyWith(color: AdminColors.warn),
                ),
              ),
            SectionCard(
              title: 'Identitas layar',
              child: Column(
                children: [
                  _field(_orgName, 'Nama lembaga', required: true),
                  const SizedBox(height: 12),
                  _field(_address, 'Alamat'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(_city, 'Kota')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Zona waktu',
                          child: TextFormField(
                            initialValue: 'Asia/Jakarta (WIB)',
                            enabled: false,
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _latitude,
                          'Latitude',
                          digits: true,
                          decimal: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _longitude,
                          'Longitude',
                          digits: true,
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Koordinat dipakai saat kota bukan Batam. Batam selalu '
                    'memakai jadwal Kemenag 0506.',
                    style: AdminText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Jadwal sholat hari ini',
              subtitle: _prayers.isEmpty
                  ? 'Belum tersedia'
                  : 'Sumber: ${_loaded.city.toLowerCase().contains('batam') ? 'myquran/Kemenag Batam' : 'perhitungan adhan'}',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in _prayers)
                    Container(
                      width: 108,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AdminColors.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.line),
                      ),
                      child: Column(
                        children: [
                          Text(entry.label, style: AdminText.caption),
                          const SizedBox(height: 3),
                          Text(
                            entry.time,
                            style: AdminText.h2.copyWith(fontSize: 19),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Ihtiyati & iqamah',
              subtitle:
                  'Ihtiyati ditambahkan ke waktu sholat. Iqamah dipakai '
                  'menghitung hitung mundur setelah adzan.',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 700;
                  return Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 90),
                          for (var i = 0; i < _prayerKeys.length; i++)
                            Expanded(
                              child: Center(
                                child: Text(
                                  _prayerLabels[i],
                                  style: AdminText.label,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const SizedBox(
                            width: 90,
                            child: Text('Ihtiyati (mnt)'),
                          ),
                          for (final key in _prayerKeys)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _number(
                                  _ihtiyati[key]!,
                                  enabled: _canEdit,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 90,
                            child: Text('Iqamah (mnt)'),
                          ),
                          for (final key in _prayerKeys)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _number(
                                  _iqamah[key]!,
                                  enabled: _canEdit,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!wide) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Geser tabel bila layar sempit.',
                          style: AdminText.caption,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _prayerKeys.length; i++)
                            SizedBox(
                              width: 150,
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(
                                  'Mode ${_prayerLabels[i]}',
                                  style: AdminText.caption,
                                ),
                                value: _prayerMode[_prayerKeys[i]] ?? true,
                                onChanged: _canEdit
                                    ? (value) => setState(
                                        () =>
                                            _prayerMode[_prayerKeys[i]] = value,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Tampilan & waktu',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          _slideDuration,
                          'Durasi slide (detik)',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          _tickerSpeed,
                          'Kecepatan ticker (px/detik)',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          _prayerDuration,
                          'Durasi mode sholat (menit)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          _khutbah,
                          'Durasi khutbah Jumat (menit)',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          _hijriOffset,
                          'Offset Hijriah (hari)',
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Offset Hijriah memajukan/memundurkan tanggal Hijriah. '
                    'Gunakan 0 bila tidak yakin.',
                    style: AdminText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Mode darurat',
              subtitle:
                  'Pesan darurat mengalahkan slideshow di TV sampai '
                  'dinonaktifkan atau batas waktu tercapai.',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan pesan darurat'),
                    subtitle: Text(
                      _emergencyActive
                          ? 'TV menampilkan pesan darurat pada sync berikutnya.'
                          : 'Tidak ada pesan darurat.',
                    ),
                    value: _emergencyActive,
                    onChanged: _canEdit
                        ? (value) => setState(() => _emergencyActive = value)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    _emergencyTitle,
                    'Judul pesan',
                    enabled: _canEdit && _emergencyActive,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _emergencyBody,
                    'Isi pesan',
                    maxLines: 4,
                    enabled: _canEdit && _emergencyActive,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: 'Warna',
                          child: DropdownButtonFormField<String>(
                            initialValue: _emergencyColor,
                            decoration: const InputDecoration(),
                            items: const [
                              DropdownMenuItem(
                                value: 'danger',
                                child: Text('Merah (darurat)'),
                              ),
                              DropdownMenuItem(
                                value: 'warn',
                                child: Text('Kuning (perhatian)'),
                              ),
                              DropdownMenuItem(
                                value: 'teal',
                                child: Text('Hijau (informasi)'),
                              ),
                            ],
                            onChanged: _canEdit && _emergencyActive
                                ? (value) => setState(
                                    () => _emergencyColor = value ?? 'danger',
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: 'Berakhir (opsional)',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _canEdit && _emergencyActive
                                ? _pickEmergencyUntil
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AdminColors.line),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _emergencyUntil == null
                                          ? 'Sampai dicabut'
                                          : Wib.dateTime(_emergencyUntil),
                                      style: AdminText.body,
                                    ),
                                  ),
                                  if (_emergencyUntil != null)
                                    InkWell(
                                      onTap: () => setState(
                                        () => _emergencyUntil = null,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: AdminColors.inkSoft,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Versi pengaturan',
              child: Wrap(
                spacing: 32,
                runSpacing: 10,
                children: [
                  _Meta(label: 'Versi', value: 'v${_loaded.version}'),
                  _Meta(
                    label: 'Terakhir diubah',
                    value: Wib.dateTime(_loaded.updatedAt),
                  ),
                  _Meta(label: 'Zona waktu', value: 'WIB (UTC+7)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool enabled = true,
    bool digits = false,
    bool decimal = false,
    int maxLines = 1,
  }) {
    return LabeledField(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: _canEdit && enabled,
        maxLines: maxLines,
        keyboardType: digits
            ? TextInputType.numberWithOptions(decimal: decimal)
            : TextInputType.text,
        inputFormatters: digits
            ? [
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'[0-9.,-]') : RegExp(r'[0-9-]'),
                ),
              ]
            : null,
        decoration: const InputDecoration(),
        validator: required
            ? (value) =>
                  (value ?? '').trim().isEmpty ? '$label wajib diisi.' : null
            : null,
      ),
    );
  }

  Widget _number(TextEditingController controller, {bool enabled = true}) {
    return TextFormField(
      controller: controller,
      enabled: _canEdit && enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return LabeledField(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: _canEdit,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminText.caption),
        const SizedBox(height: 2),
        Text(value, style: AdminText.label.copyWith(color: AdminColors.ink)),
      ],
    );
  }
}
