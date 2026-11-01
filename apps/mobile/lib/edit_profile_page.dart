// Edit Profil ala mock Stitch. State tersimpan lokal (ProfileStore);
// backend + foto asli ikut #14.
import 'package:flutter/material.dart';

import 'profile.dart';
import 'vote.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _name = TextEditingController(text: ProfileStore.name);
  late final _headline =
      TextEditingController(text: ProfileStore.headline);
  late final _about = TextEditingController(text: ProfileStore.about);
  late final _location =
      TextEditingController(text: ProfileStore.location);
  late final _website = TextEditingController(text: ProfileStore.website);
  late final List<String> _topics = [...ProfileStore.topics];
  late bool _badge = ProfileStore.showBadge;
  late bool _dm = ProfileStore.allowDm;
  late bool _activity = ProfileStore.showActivity;

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _about.dispose();
    _location.dispose();
    _website.dispose();
    super.dispose();
  }

  void _save() {
    ProfileStore.name = _name.text.trim();
    ProfileStore.headline = _headline.text.trim();
    ProfileStore.about = _about.text.trim();
    ProfileStore.location = _location.text.trim();
    ProfileStore.website = _website.text.trim();
    ProfileStore.topics = [..._topics];
    ProfileStore.showBadge = _badge;
    ProfileStore.allowDm = _dm;
    ProfileStore.showActivity = _activity;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil tersimpan di perangkat.')),
    );
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what segera hadir (#14)')),
    );
  }

  Future<void> _addTopic() async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Topik Baru'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '@teknologi',
            border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.all(Radius.circular(12))),
            isDense: true,
          ),
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(ctrl.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Tambah')),
        ],
      ),
    );
    final t = (v ?? '').replaceAll('@', '').trim();
    if (t.isNotEmpty && !_topics.contains(t)) {
      setState(() => _topics.add(t));
    }
  }

  Widget _label(String s, {String? counter}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(s,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (counter != null) ...[
            const Spacer(),
            Text(counter,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF65676B))),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController c,
      {String? hint,
      int maxLines = 1,
      int? maxLength,
      IconData? icon,
      TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: const Color(0xFF65676B)),
          border: const OutlineInputBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(12))),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          counterText: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isEmpty
        ? 'S'
        : _name.text.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Edit Profil',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                  onPressed: _save,
                  child: const Text('Simpan')),
            ),
          ]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFE4E6EB))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informasi Dasar',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              const Color(0xFFE7F3FF),
                          child: Text(initial,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: sabaBlue)),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: GestureDetector(
                            onTap: () => _soon('Ubah foto'),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: sabaBlue,
                              child: Icon(Icons.camera_alt,
                                  size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _soon('Ubah foto'),
                                child: const Text('Ubah Foto',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                        color: sabaBlue)),
                              ),
                              const Text('  •  ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF65676B))),
                              GestureDetector(
                                onTap: () => _soon('Hapus foto'),
                                child: const Text('Hapus',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF65676B))),
                              ),
                            ],
                          ),
                          const Text('Format JPG, PNG maks. 2MB',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF65676B))),
                        ],
                      ),
                    ),
                  ],
                ),
                _label('Nama Lengkap'),
                _field(_name, hint: 'Nama lengkap'),
                _label('Jabatan & Organisasi (Bio Singkat)'),
                _field(_headline,
                    hint: 'Principal Designer di SABA'),
                _label('Tentang',
                    counter: '${_about.text.length}/240'),
                _field(_about,
                    hint: 'Ceritakan tentang dirimu…',
                    maxLines: 4,
                    maxLength: 240),
                _label('Lokasi Saat Ini'),
                _field(_location,
                    hint: 'Jakarta, Indonesia',
                    icon: Icons.location_on_outlined),
                _label('Situs Web / Portofolio'),
                _field(_website,
                    hint: 'https://namamu.id',
                    icon: Icons.language_outlined,
                    keyboard: TextInputType.url),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFE4E6EB))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kredensial & Afiliasi',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Pengalaman',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _soon('Tambah pengalaman'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                const Text('Belum ada pengalaman.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF65676B))),
                Row(
                  children: [
                    const Text('Pendidikan',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _soon('Tambah pendidikan'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                const Text('Belum ada pendidikan.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF65676B))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Topik',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${_topics.length} Terpilih',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF65676B))),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _topics)
                      Container(
                        padding: const EdgeInsets.only(
                            left: 10, top: 4, bottom: 4, right: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE7F3FF),
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('@$t',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: sabaBlue)),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _topics.remove(t)),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close,
                                    size: 14, color: sabaBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: _addTopic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(999),
                            border: Border.all(
                                color: sabaBlue)),
                        child: const Text('+ Topik Baru',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sabaBlue)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFE4E6EB))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Privasi & Visibilitas Publik',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                _toggle('Lencana Top Kreator',
                    'Tampilkan lencana reputasi di samping nama pada feed diskusi',
                    _badge, (v) => setState(() => _badge = v)),
                _toggle('Izinkan Pesan Langsung (DM)',
                    'Beri izin sesama anggota komunitas untuk memulai obrolan',
                    _dm, (v) => setState(() => _dm = v)),
                _toggle('Aktivitas di Feed Publik',
                    'Tampilkan jawaban & tanggapan favorit Anda di tab linimasa',
                    _activity,
                    (v) => setState(() => _activity = v)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
                onPressed: _save,
                child: const Text('Simpan Perubahan')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    child: const Text('Batal')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    icon: const Icon(
                        Icons.visibility_outlined,
                        size: 16),
                    label: const Text('Pratinjau')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(
      String title, String sub, bool v, ValueChanged<bool> on) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF65676B))),
              ],
            ),
          ),
          Switch(value: v, activeThumbColor: sabaBlue, onChanged: on),
        ],
      ),
    );
  }
}
