// Profil ala mock Stitch: bio Tentang (dummy, tulis via Edit Profil nanti),
// statistik lokal, dan kotak upload (segera hadir, #14).
// Murni lokal tanpa backend; gaya ikut kartu feed (putih, radius 16).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feed.dart';
import 'vote.dart';

/// Profil lokal sesi ini (in-memory, pola VoteStore).
/// Backend (nama/bio/topik + auth) ikut #14.
class ProfileStore {
  static String name = '';
  static String headline = '';
  static String about = '';
  static String location = '';
  static String website = '';
  static List<String> topics = [];
  static bool showBadge = true;
  static bool allowDm = true;
  static bool showActivity = true;

  static void reset() {
    name = '';
    headline = '';
    about = '';
    location = '';
    website = '';
    topics = [];
    showBadge = true;
    allowDm = true;
    showActivity = true;
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage(
      {super.key,
      required this.feed,
      required this.onEdit,
      required this.onLogin});

  final List<FeedArticle> feed;
  final Future<void> Function() onEdit;
  final void Function() onLogin;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what segera hadir')),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E6EB))),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        ProfileStore.name.isEmpty ? 'Pengguna SABA' : ProfileStore.name;
    final headline = ProfileStore.headline.isEmpty
        ? 'Kreator & pembaca komunitas SABA'
        : ProfileStore.headline;
    final about = ProfileStore.about.isEmpty
        ? 'Suka coba skincare lokal dan review jujur tiap minggu. Fokus: hair care & body care.'
        : ProfileStore.about;
    final initial = ProfileStore.name.trim().isEmpty
        ? 'S'
        : ProfileStore.name.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              children: [
                const Text('SABA',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: sabaBlue)),
                const SizedBox(width: 8),
                const Text('Detail Akun',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  color: const Color(0xFF65676B),
                  onPressed: widget.onLogin,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: sabaBlue, width: 3)),
                        child: Text(initial,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: sabaBlue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF65676B))),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE7F3FF),
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: const Text('PRO',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: sabaBlue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tentang',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(about,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF050505))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE7F3FF),
                            borderRadius:
                                BorderRadius.circular(8)),
                        child: const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: sabaBlue),
                      ),
                      const SizedBox(width: 8),
                      const Text('Aksi Profil',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE7F3FF),
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: const Text('Aktif',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sabaBlue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                            onPressed: () async {
                              await widget.onEdit();
                              if (context.mounted) {
                                setState(() {});
                              }
                            },
                            child: const Text('Edit Profil')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFE4E6EB),
                              foregroundColor:
                                  const Color(0xFF050505),
                            ),
                            onPressed: () =>
                                _soon('Insights'),
                            child:
                                const Text('Lihat Insights')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(
                            text:
                                'SABA — ulasan produk dari video kreator'));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                                content: Text(
                                    'Profil disalin')));
                      },
                      icon: const Icon(Icons.share_outlined,
                          size: 16),
                      label:
                          const Text('Bagikan Profil'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _stat(Icons.article_outlined,
                        '${widget.feed.length}', 'Artikel')),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(
                        Icons.thumb_up_outlined,
                        compactVotes(VoteStore.upvoted.length),
                        'Setuju saya')),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.video_library_outlined,
                          size: 18, color: sabaBlue),
                      SizedBox(width: 6),
                      Text('Konten Multimedia',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Spacer(),
                      Text('Beta',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF65676B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _soon('Upload video (#14)'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  const Color(0xFFE4E6EB))),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color:
                                    const Color(0xFFF0F2F5),
                                borderRadius:
                                    BorderRadius.circular(
                                        8)),
                            child: const Icon(
                                Icons.videocam_off_outlined,
                                size: 20,
                                color: Color(0xFF65676B)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Upload video',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600)),
                                Text(
                                    'Format MP4, MOV maks 50MB',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(
                                            0xFF65676B))),
                              ],
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6),
                            decoration: BoxDecoration(
                                color:
                                    const Color(0xFFF0F2F5),
                                borderRadius:
                                    BorderRadius.circular(
                                        999)),
                            child: const Text('Segera Hadir',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w600,
                                    color:
                                        Color(0xFF65676B))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E6EB))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFE7F3FF),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: sabaBlue),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF65676B))),
            ],
          ),
        ],
      ),
    );
  }
}
