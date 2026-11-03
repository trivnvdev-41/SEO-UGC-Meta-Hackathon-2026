// Profil ala mockup 10: header Insight, avatar verifikasi, aksi, statistik,
// daftar Artikel saya. Murni lokal tanpa backend.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feed.dart';
import 'saba_screens.dart';
import 'saba_theme.dart';
import 'saba_widgets.dart';
import 'vote.dart';

/// Profil lokal sesi ini (in-memory, pola VoteStore).
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
      required this.onLogin,
      required this.onUpload,
      required this.onOpenArticle});

  final List<FeedArticle> feed;
  final Future<void> Function() onEdit;
  final void Function() onLogin;
  final Future<void> Function() onUpload;
  final void Function(String id) onOpenArticle;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _openInsights() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InsightPage(feed: widget.feed)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => SettingsPage(onLogout: widget.onLogin)),
    );
  }

  void _openMenu() {
    showProfileMenu(
      context,
      onEdit: () async {
        await widget.onEdit();
        if (context.mounted) setState(() {});
      },
      onInsights: _openInsights,
      onShare: _shareProfile,
    );
  }

  Future<void> _shareProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(
        text: 'SABA — ulasan produk dari video kreator'));
    messenger.showSnackBar(const SnackBar(content: Text('Profil disalin')));
  }

  void _openArticle(String id) => widget.onOpenArticle(id);

  @override
  Widget build(BuildContext context) {
    final name =
        ProfileStore.name.isEmpty ? 'Dimas Pratama' : ProfileStore.name;
    final headline = ProfileStore.headline.isEmpty
        ? 'Principal Designer & Software Architect • Spesialis Design System & AI-UI'
        : ProfileStore.headline;
    final initial = name.trim().isEmpty
        ? 'D'
        : name.trim()[0].toUpperCase();
    return Scaffold(
      backgroundColor: SabaColors.bgWarm,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header: Insight pill + gear + menu.
            Row(
              children: [
                GestureDetector(
                  onTap: _openInsights,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: SabaColors.primary,
                        borderRadius:
                            BorderRadius.circular(SabaRadius.pill)),
                    child: const Text('Insight',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon:
                      const Icon(Icons.settings_outlined, size: 22),
                  color: SabaColors.ink,
                  onPressed: _openSettings,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert, size: 22),
                  color: SabaColors.ink,
                  onPressed: _openMenu,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Kartu identitas.
            SabaCard(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _openMenu,
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: SabaColors.primary,
                                  width: 3)),
                          child: Text(initial,
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: SabaColors.primary)),
                        ),
                      ),
                      if (ProfileStore.showBadge)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: SabaColors.primary,
                            child: Icon(Icons.check,
                                size: 13, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: SabaColors.greyFill,
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: Text(
                            ProfileStore.name.isEmpty
                                ? '@ Belum klaim'
                                : '@${ProfileStore.name.replaceAll(' ', '').toLowerCase()}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SabaColors.muted2)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: SabaColors.chipBlueBg,
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: const Text('PRO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: SabaColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: SabaColors.muted2)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Aksi Profil.
            SabaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: SabaColors.chipBlueBg,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.people_outline,
                            size: 16, color: SabaColors.primary),
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
                            color: SabaColors.chipBlueBg,
                            borderRadius:
                                BorderRadius.circular(999)),
                        child: const Text('Aktif',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: SabaColors.primary)),
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
                              backgroundColor: SabaColors.greyFill,
                              foregroundColor: SabaColors.ink,
                            ),
                            onPressed: _openInsights,
                            child:
                                const Text('Lihat Insights')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _shareProfile,
                      child: const Text('Bagikan Profil'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Statistik.
            Row(
              children: [
                Expanded(
                    child: _stat(Icons.article_outlined,
                        '${widget.feed.length}', 'Artikel saya')),
                const SizedBox(width: 12),
                Expanded(
                    child: _stat(
                        Icons.thumb_up_outlined,
                        compactVotes(VoteStore.upvoted.length),
                        'Setuju saya')),
              ],
            ),
            const SizedBox(height: 12),
            // Artikel saya.
            SabaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          size: 18, color: SabaColors.primary),
                      const SizedBox(width: 6),
                      const Text('Artikel saya',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${widget.feed.length} Konten',
                          style: const TextStyle(
                              fontSize: 11,
                              color: SabaColors.muted2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.feed.isEmpty)
                    const Text('Belum ada artikel.',
                        style: TextStyle(
                            fontSize: 12,
                            color: SabaColors.muted2)),
                  for (final a in widget.feed)
                    GestureDetector(
                      onTap: () => _openArticle(a.id),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(a.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (a.rating != null) ...[
                                        const Icon(Icons.star,
                                            size: 12,
                                            color: SabaColors.star),
                                        const SizedBox(width: 2),
                                        Text(
                                            a.rating!.split('/').first,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.bold)),
                                        const SizedBox(width: 6),
                                      ],
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                            color:
                                                SabaColors.greyFill,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    4)),
                                        child: Text(
                                            '@${a.brand.isNotEmpty ? a.brand : 'ulasan'}',
                                            style:
                                                const TextStyle(
                                                    fontSize: 10,
                                                    color: SabaColors
                                                        .muted2)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                          timeAgo(a.createdAt).isEmpty
                                              ? 'baru saja'
                                              : timeAgo(a.createdAt),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  SabaColors.muted2)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 18, color: SabaColors.muted2),
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
          borderRadius: BorderRadius.circular(SabaRadius.card),
          border: Border.all(color: SabaColors.borderCard)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: SabaColors.chipBlueBg,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: SabaColors.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: SabaColors.muted2)),
            ],
          ),
        ],
      ),
    );
  }
}
