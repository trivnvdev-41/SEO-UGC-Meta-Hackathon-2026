// Layar baru dari 14 PNG mockup (saba-handoff). Semua dummy lokal,
// backend tetap out-of-scope; Login juga dummy (pop langsung).
import 'package:flutter/material.dart';

import 'feed.dart';
import 'saba_theme.dart';
import 'saba_widgets.dart';
import 'vote.dart';

/// 01 - Splash: logo S di atas primary, lanjut otomatis.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.child),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: SabaColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('S',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            SizedBox(height: 8),
            Text('SABA',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            SizedBox(height: 4),
            Text('Ruang Dialog & Komunitas',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

/// 05 - Jelajah: chip merek + daftar artikel merek itu.
class JelajahPage extends StatefulWidget {
  const JelajahPage({super.key, required this.feed, required this.onOpen});

  final List<FeedArticle> feed;
  final void Function(String id) onOpen;

  @override
  State<JelajahPage> createState() => _JelajahPageState();
}

class _JelajahPageState extends State<JelajahPage> {
  String? _brand;

  @override
  Widget build(BuildContext context) {
    final brands = feedBrands(widget.feed);
    final list = filterFeed(widget.feed, _brand);
    return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: const SabaHeader(title: 'Jelajah'),
      body: ListView(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('Semua', _brand == null, () => setState(() => _brand = null)),
                for (final b in brands) ...[
                  const SizedBox(width: 8),
                  _chip(b, _brand == b, () => setState(() => _brand = b)),
                ],
              ],
            ),
          ),
          const SizedBox(height: SabaSpacing.gapCard),
          if (list.isEmpty)
            const SabaCard(child: Text('Belum ada artikel di topik ini.')),
          for (final a in list) ...[
            SabaCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(a.title, style: SabaTextStyles.cardTitle),
                subtitle: Text(a.excerpt,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: SabaTextStyles.excerpt),
                onTap: () => widget.onOpen(a.id),
              ),
            ),
            const SizedBox(height: SabaSpacing.gapCard),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? SabaColors.primary : SabaColors.greyFill,
          borderRadius: BorderRadius.circular(SabaRadius.pill),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : SabaColors.body,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }
}

/// 06 - Kotak Masuk: daftar info lokal (belum ada backend).
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: const SabaHeader(title: 'Kotak Masuk'),
      body: ListView(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        children: const [
          SabaCard(
              child: ListTile(
                  leading: Icon(Icons.check_circle_outline, color: SabaColors.primary),
                  title: Text('Selamat datang di SABA', style: SabaTextStyles.cardTitle),
                  subtitle: Text('Ketuk + untuk upload video pertama.', style: SabaTextStyles.meta))),
          SizedBox(height: SabaSpacing.gapCard),
          SabaCard(
              child: ListTile(
                  leading: Icon(Icons.info_outline, color: SabaColors.muted),
                  title: Text('Belum ada notifikasi baru', style: SabaTextStyles.cardTitle),
                  subtitle: Text('Info artikel jadi muncul di sini.', style: SabaTextStyles.meta))),
        ],
      ),
    );
  }
}

/// 12 - Pengaturan Sukses: check-lg + tombol kembali.
class SettingsSuccessPage extends StatelessWidget {
  const SettingsSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabaColors.bgWarm,
      appBar: const SabaHeader(title: 'Pengaturan'),
      body: Padding(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        child: SabaCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SabaIcons.checkLg(),
              const SizedBox(height: 12),
              const Text('Pengaturan tersimpan', style: SabaTextStyles.sectionTitle),
              const SizedBox(height: 4),
              const Text('Preferensi akunmu sudah diperbarui.',
                  style: TextStyle(fontSize: 12, color: SabaColors.muted)),
              const SizedBox(height: 16),
              SabaPrimaryButton(
                label: 'Kembali',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 13 - Bottom Sheet Menu Profil.
Future<void> showProfileMenu(BuildContext context,
    {required VoidCallback onEdit, required VoidCallback onInsights}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: SabaColors.borderSoft,
                  borderRadius: BorderRadius.circular(SabaRadius.pill))),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: SabaColors.primary),
            title: const Text('Edit Profil'),
            onTap: () {
              Navigator.of(ctx).pop();
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.insights_outlined, color: SabaColors.primary),
            title: const Text('Lihat Insights'),
            onTap: () {
              Navigator.of(ctx).pop();
              onInsights();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: SabaColors.primary),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SettingsSuccessPage()));
            },
          ),
        ],
      ),
    ),
  );
}

/// 14 - Insight Threads Light: angka tabular ala mock (2.264 / 1.702).
class InsightPage extends StatelessWidget {
  const InsightPage({super.key, required this.feed});

  final List<FeedArticle> feed;

  @override
  Widget build(BuildContext context) {
    final views = feed.fold<int>(0, (n, a) => n + baseVotes(a.id));
    return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: const SabaHeader(title: 'Insights'),
      body: ListView(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        children: [
          const SabaCard(
            child: Row(
              children: [
                Icon(Icons.star, color: SabaColors.star),
                SizedBox(width: 8),
                Text('Performa Threads', style: SabaTextStyles.sectionTitle),
              ],
            ),
          ),
          const SizedBox(height: SabaSpacing.gapCard),
          SabaCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Views', style: SabaTextStyles.meta),
                      Text('$views',
                          style: SabaTextStyles.tabularNumber.copyWith(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: SabaColors.successGreenBg,
                      borderRadius: BorderRadius.circular(SabaRadius.pill)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: SabaColors.successLineGreen),
                      SizedBox(width: 4),
                      Text('Naik', style: TextStyle(fontSize: 11, color: SabaColors.successLineGreen)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 08/09 - Langkah upload: 1=Sumber (sheet galeri tetap), 2=Frame Transkrip.
/// Dipakai ulang: progress + _StepCycler di main.dart = langkah 2.
class UploadSourceSheet extends StatelessWidget {
  const UploadSourceSheet({super.key, required this.onGallery});

  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: SabaColors.borderSoft,
                    borderRadius: BorderRadius.circular(SabaRadius.pill))),
          ),
          const SizedBox(height: 12),
          const Text('Buat artikel dari video', style: SabaTextStyles.sectionTitle),
          const SizedBox(height: 4),
          const Text('Pilih video dari galeri — Langkah 1 dari 3: Sumber.',
              style: TextStyle(fontSize: 12, color: SabaColors.muted)),
          const SizedBox(height: 12),
          SabaPrimaryButton(label: 'Pilih video dari galeri', onPressed: onGallery),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal')),
        ],
      ),
    );
  }
}
