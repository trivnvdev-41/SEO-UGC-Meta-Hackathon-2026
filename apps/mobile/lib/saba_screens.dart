// Layar baru dari 14 PNG mockup (saba-handoff). Semua dummy lokal,
// backend tetap out-of-scope; Login juga dummy (pop langsung).
import 'package:flutter/material.dart';

import 'feed.dart';
import 'saba_theme.dart';
import 'saba_widgets.dart';
import 'upload.dart';
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
          ],
        ),
      ),
    );
  }
}

/// 05 - Jelajah: cari, chip kategori, terakhir dicari, topik + ikuti, hot.
class JelajahPage extends StatefulWidget {
  const JelajahPage({super.key, required this.feed, required this.onOpen});

  final List<FeedArticle> feed;
  final void Function(String id) onOpen;

  @override
  State<JelajahPage> createState() => _JelajahPageState();
}

class _JelajahPageState extends State<JelajahPage> {
  final _search = TextEditingController();
  String _query = '';
  int _cat = 0; // 0 Semua, 1 Topik, 2 Komunitas, 3 Kreator
  final List<String> _recent = [];
  final Set<String> _following = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FeedArticle> get _filtered {
    var list = widget.feed;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((a) =>
              '${a.title} ${a.excerpt} ${a.brand} ${a.creator}'
                  .toLowerCase()
                  .contains(q))
          .toList();
    }
    if (_cat == 1) {
      list = list.where((a) => a.brand.isNotEmpty).toList();
    } else if (_cat == 2) {
      list = list.where((a) => a.brand.isEmpty).toList();
    } else if (_cat == 3) {
      list = list.where((a) => a.creator.isNotEmpty).toList();
    }
    return list;
  }

  List<FeedArticle> get _hot {
    final list = [...widget.feed]
      ..sort((a, b) => baseVotes(b.id).compareTo(baseVotes(a.id)));
    return list.take(3).toList();
  }

  void _submitSearch(String v) {
    final q = v.trim();
    if (q.isNotEmpty && !_recent.contains(q)) {
      setState(() {
        _recent.insert(0, q);
        if (_recent.length > 5) _recent.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const cats = ['Semua', 'Topik', 'Komunitas', 'Kreator'];
    final brands = feedBrands(widget.feed);
    return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: const SabaHeader(title: 'Jelajah'),
      body: ListView(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        children: [
          // Search.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(SabaRadius.pill),
                border: Border.all(color: SabaColors.borderCard)),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: _submitSearch,
              decoration: const InputDecoration(
                hintText: 'Cari di SABA…',
                border: InputBorder.none,
                isDense: true,
                icon: Icon(Icons.search,
                    size: 18, color: SabaColors.muted2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Kategori.
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _cat = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _cat == i
                        ? SabaColors.primary
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(SabaRadius.pill),
                    border: Border.all(
                        color: _cat == i
                            ? SabaColors.primary
                            : SabaColors.borderSoft),
                  ),
                  child: Text(cats[i],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _cat == i
                              ? Colors.white
                              : SabaColors.body)),
                ),
              ),
            ),
          ),
          // Terakhir dicari.
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: SabaSpacing.gapCard),
            SabaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Terakhir dicari',
                      style: SabaTextStyles.sectionTitle),
                  const SizedBox(height: 6),
                  for (final r in _recent)
                    GestureDetector(
                      onTap: () {
                        _search.text = r;
                        setState(() => _query = r);
                      },
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.history,
                                size: 16, color: SabaColors.muted2),
                            const SizedBox(width: 8),
                            Text(r,
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Topik + ikuti.
          if (brands.isNotEmpty) ...[
            const SizedBox(height: SabaSpacing.gapCard),
            SabaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jelajahi topik • Ikuti favoritmu',
                      style: SabaTextStyles.sectionTitle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in brands)
                        Container(
                          padding: const EdgeInsets.only(
                              left: 10, top: 4, bottom: 4, right: 4),
                          decoration: BoxDecoration(
                              color: SabaColors.chipBlueBg,
                              borderRadius: BorderRadius.circular(
                                  SabaRadius.pill)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('@$b',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: SabaColors.primary)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() {
                                  if (!_following.remove(b)) {
                                    _following.add(b);
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: _following.contains(b)
                                          ? SabaColors.primary
                                          : Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(
                                              SabaRadius.pill)),
                                  child: Text(
                                      _following.contains(b)
                                          ? 'Diikuti'
                                          : 'Ikuti',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _following
                                                  .contains(b)
                                              ? Colors.white
                                              : SabaColors.primary)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Hot hari ini.
          if (_hot.isNotEmpty) ...[
            const SizedBox(height: SabaSpacing.gapCard),
            SabaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hot hari ini • Lihat Semua',
                      style: SabaTextStyles.sectionTitle),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _hot.length; i++)
                    GestureDetector(
                      onTap: () => widget.onOpen(_hot[i].id),
                      child: Padding(
                        padding: EdgeInsets.only(
                            bottom: i < _hot.length - 1 ? 8 : 0),
                        child: Text(
                            '${i + 1}. ${_hot[i].title} • ${compactVotes(baseVotes(_hot[i].id))} panas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Hasil.
          if (_query.isNotEmpty || _cat != 0) ...[
            const SizedBox(height: SabaSpacing.gapCard),
            if (_filtered.isEmpty)
              const SabaCard(
                  child: Text('Tidak ada hasil untuk filter ini.'))
            else
              for (final a in _filtered) ...[
                SabaCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SabaTextStyles.cardTitle),
                    subtitle: Text(a.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SabaTextStyles.excerpt),
                    onTap: () => widget.onOpen(a.id),
                  ),
                ),
                const SizedBox(height: SabaSpacing.gapCard),
              ],
          ],
        ],
      ),
    );
  }
}

/// 06 - Kotak Masuk: riwayat job upload (selesai / progres / gagal).
class InboxPage extends StatelessWidget {
  const InboxPage(
      {super.key,
      required this.jobs,
      required this.onOpen,
      required this.onRetry});

  final List<JobRecord> jobs;
  final void Function(String jobId) onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabaColors.bgCool,
      appBar: const SabaHeader(title: 'Kotak Masuk'),
      body: jobs.isEmpty
          ? const Center(
              child: Text('Belum ada aktivitas upload.\nKetuk + untuk mulai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: SabaColors.muted2)))
          : ListView(
              padding: const EdgeInsets.all(SabaSpacing.screen),
              children: [
                for (final j in jobs) ...[
                  _jobCard(context, j),
                  const SizedBox(height: SabaSpacing.gapCard),
                ],
              ],
            ),
    );
  }

  Widget _jobCard(BuildContext context, JobRecord job) {
    final pct = (job.pct * 100).floor();
    return SabaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusIcon(job),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_subtitle(job, pct),
                        style: const TextStyle(
                            fontSize: 12, color: SabaColors.muted2)),
                  ],
                ),
              ),
            ],
          ),
          if (job.status == 'converting') ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(SabaRadius.pill),
              child: LinearProgressIndicator(
                value: job.pct,
                minHeight: 8,
                backgroundColor: SabaColors.track,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    SabaColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text('$pct% • Estimasi 2 mnt',
                style: const TextStyle(
                    fontSize: 11, color: SabaColors.muted2)),
          ],
          if (job.status != 'converting') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _chip(
                    job.status == 'done' ? 'Selesai' : 'Gagal',
                    job.status == 'done'
                        ? SabaColors.chipBlueBg
                        : SabaColors.failBg,
                    job.status == 'done'
                        ? SabaColors.primary
                        : SabaColors.fail),
                const SizedBox(width: 8),
                if (job.status == 'done')
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16)),
                      onPressed: () => onOpen(job.id),
                      child: const Text('Lihat artikel'))
                else
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16)),
                      onPressed: onRetry,
                      child: const Text('Coba lagi')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon(JobRecord job) {
    if (job.status == 'done') {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: SabaColors.primary, shape: BoxShape.circle),
        child:
            const Icon(Icons.check, size: 20, color: Colors.white),
      );
    }
    if (job.status == 'failed') {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: SabaColors.failBg, shape: BoxShape.circle),
        child: const Text('!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: SabaColors.fail)),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          color: SabaColors.greyFill, shape: BoxShape.circle),
      child: const Icon(Icons.hourglass_bottom,
          size: 20, color: SabaColors.muted2),
    );
  }

  String _subtitle(JobRecord job, int pct) {
    final ago = DateTime.now().difference(job.at);
    final when = ago.inMinutes < 1
        ? 'baru saja'
        : ago.inHours < 1
            ? '${ago.inMinutes} mnt lalu'
            : '${ago.inHours} jam lalu';
    if (job.status == 'done') return 'Convert selesai • $when';
    if (job.status == 'failed') {
      return 'Gagal • ${(job.error ?? '').split(':').first}';
    }
    return 'Mengonversi… • $pct%';
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(SabaRadius.pill)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// 12 - Pengaturan: kartu sukses (bila baru publish) + notif + tentang + keluar.
class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {super.key,
      this.publishedJobId,
      this.onOpenArticle,
      this.onShareArticle,
      required this.onLogout});

  final String? publishedJobId;
  final VoidCallback? onOpenArticle;
  final VoidCallback? onShareArticle;
  final VoidCallback onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notif = true;

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what segera hadir')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabaColors.bgWarm,
      appBar: const SabaHeader(title: 'Pengaturan'),
      body: ListView(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        children: [
          if (widget.publishedJobId != null)
            SabaCard(
              child: Column(
                children: [
                  SabaIcons.check(size: 64),
                  const SizedBox(height: 8),
                  const Text('Terpublish!',
                      style: SabaTextStyles.sectionTitle),
                  const SizedBox(height: 4),
                  const Text(
                      'Artikel kamu sudah live dan bisa dibagikan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: SabaColors.muted2)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                            onPressed: widget.onOpenArticle,
                            child: const Text('Lihat artikel')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                            onPressed: widget.onShareArticle,
                            child: const Text('Bagikan')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (widget.publishedJobId != null)
            const SizedBox(height: SabaSpacing.gapCard),
          SabaCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Notifikasi',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                        value: _notif,
                        activeThumbColor: SabaColors.primary,
                        onChanged: (v) =>
                            setState(() => _notif = v)),
                  ],
                ),
                const Divider(
                    height: 16, color: SabaColors.borderSoft),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tentang',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right,
                      color: SabaColors.muted2),
                  onTap: () => _soon('Tentang SABA'),
                ),
                const Divider(
                    height: 16, color: SabaColors.borderSoft),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Keluar',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SabaColors.fail)),
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 13 - Bottom Sheet Menu Profil: baris teks ala mockup.
Future<void> showProfileMenu(BuildContext context,
    {required VoidCallback onEdit,
    required VoidCallback onInsights,
    required VoidCallback onShare}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: SabaColors.borderSoft,
                    borderRadius:
                        BorderRadius.circular(SabaRadius.pill))),
          ),
          _sheetRow(ctx, 'Bagikan Profil', onShare),
          _sheetRow(ctx, 'Salin link', () {
            Navigator.of(ctx).pop();
            onShare();
          }),
          _sheetRow(ctx, 'Lihat versi publik', () {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Versi publik segera hadir')));
          }),
          _sheetRow(ctx, 'Edit Profil', () {
            Navigator.of(ctx).pop();
            onEdit();
          }),
          _sheetRow(ctx, 'Lihat Insights', () {
            Navigator.of(ctx).pop();
            onInsights();
          }),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                          content: Text('Laporan terkirim. Terima kasih.'))),
                  child: const Text('Laporkan',
                      style: TextStyle(fontSize: 15)),
                ),
                const Text('   •   ',
                    style: TextStyle(
                        fontSize: 15, color: SabaColors.muted2)),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal',
                      style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _sheetRow(
    BuildContext ctx, String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(label, style: const TextStyle(fontSize: 15)),
    ),
  );
}
/// 14 - Insight Threads Light: angka tabular + grafik + daftar posts.
class InsightPage extends StatefulWidget {
  const InsightPage({super.key, required this.feed});

  final List<FeedArticle> feed;

  @override
  State<InsightPage> createState() => _InsightPageState();
}

class _InsightPageState extends State<InsightPage> {
  int _mainTab = 0; // 0 Overview, 1 Audience
  int _postTab = 0; // 0 Threads, 1 Latest, 2 Most views

  List<FeedArticle> _posts() {
    final list = [...widget.feed];
    if (_postTab == 2) {
      list.sort((a, b) => baseVotes(b.id).compareTo(baseVotes(a.id)));
    } else if (_postTab == 1) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  List<double> _demo(int seed) {
    // Bentuk kurva demo ala mockup (naik-turun lalu datar).
    final n = (seed % 7) / 7;
    return [0.2, 0.9, 0.35, 0.75, 0.3, 0.2 + n * 0.1, 0.18, 0.18, 0.17];
  }

  Widget _metric(String label, String value, String pct) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: SabaColors.bgCool,
          borderRadius: BorderRadius.circular(SabaRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: SabaColors.muted2)),
          const SizedBox(height: 2),
          Text(value,
              style: SabaTextStyles.tabularNumber.copyWith(
                  fontSize: 26, fontWeight: FontWeight.w800)),
          Text(pct,
              style: SabaTextStyles.tabularNumber.copyWith(
                  fontSize: 11, color: SabaColors.successLineGreen)),
        ],
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(width: 56, height: 56, color: SabaColors.ink);
  }

  @override
  Widget build(BuildContext context) {
    final views =
        widget.feed.fold<int>(0, (n, a) => n + baseVotes(a.id));
    final viewers = (views * 0.75).floor();
    return Scaffold(
      backgroundColor: SabaColors.card,
      appBar: const SabaHeader(title: 'Insights'),
      body: ListView(
        padding: const EdgeInsets.all(SabaSpacing.screen),
        children: [
          // Tab utama.
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mainTab = i),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: _mainTab == i
                                      ? SabaColors.ink
                                      : Colors.transparent,
                                  width: 2))),
                      child: Text(['Overview', 'Audience'][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: _mainTab == i
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: SabaColors.ink)),
                    ),
                  ),
                ),
            ],
          ),
          if (_mainTab == 1)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                  child: Text('Data audiens segera hadir.',
                      style: TextStyle(
                          fontSize: 13, color: SabaColors.muted2))),
            )
          else ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Text('Profile (i)', style: SabaTextStyles.sectionTitle),
                Spacer(),
                Text('30 days v',
                    style:
                        TextStyle(fontSize: 12, color: SabaColors.muted2)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _metric('Views', '$views', '+37,63%')),
                const SizedBox(width: 10),
                Expanded(
                    child: _metric('Viewers', '$viewers', '+28,26%')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(height: 120, child: _Sparkline(values: _demo(views))),
            const Text('Okt 10   Okt 22   Nov 1',
                style:
                    TextStyle(fontSize: 10, color: SabaColors.muted2)),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text('Posts (i)', style: SabaTextStyles.sectionTitle),
                Spacer(),
                Text('90 days v',
                    style:
                        TextStyle(fontSize: 12, color: SabaColors.muted2)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _postTab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _postTab == i
                              ? SabaColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(
                              SabaRadius.pill),
                          border: Border.all(
                              color: _postTab == i
                                  ? SabaColors.primary
                                  : SabaColors.borderSoft),
                        ),
                        child: Text(
                            ['Threads', 'Latest', 'Most views'][i],
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _postTab == i
                                    ? Colors.white
                                    : SabaColors.body)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final a in _posts()) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: SabaColors.bgCool,
                    borderRadius:
                        BorderRadius.circular(SabaRadius.card)),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(SabaRadius.img),
                      child: a.images.isNotEmpty
                          ? Image.network(a.images.first,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _thumbFallback())
                          : _thumbFallback(),
                    ),
                    const SizedBox(width: 10),
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
                          Text(
                              '${timeAgo(a.createdAt).isEmpty ? 'baru' : timeAgo(a.createdAt)} • Hati ${compactVotes(baseVotes(a.id))} • Komen ${baseVotes(a.id) ~/ 6}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: SabaColors.muted2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparkPainter(values));
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = SabaColors.ink
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - values[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values;
}

/// 07 - Langkah 1 Sumber (dipakai di bottom sheet).
/// 08 - Langkah 2 Frame Transkrip = status converting di kartu home/Inbox
/// (server mentranskrip otomatis; tanpa edit manual).
class UploadSourceSheet extends StatefulWidget {
  const UploadSourceSheet({super.key, required this.onGallery});

  final void Function(List<String> refs)? onGallery;

  @override
  State<UploadSourceSheet> createState() => _UploadSourceSheetState();
}

class _UploadSourceSheetState extends State<UploadSourceSheet> {
  final _refs = TextEditingController();

  @override
  void dispose() {
    _refs.dispose();
    super.dispose();
  }

  /// Pecah koma/baris baru/spasi, saring https, maks 3.
  List<String> _parseRefs() {
    final out = <String>[];
    for (final part in _refs.text.split(RegExp(r'[\s,]+'))) {
      final u = part.trim();
      if (u.startsWith('https://') && !out.contains(u)) out.add(u);
      if (out.length >= 3) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
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
                      borderRadius:
                          BorderRadius.circular(SabaRadius.pill))),
            ),
            const SizedBox(height: 12),
            const SabaStepper(current: 1),
            const SizedBox(height: 16),
            const SabaCard(
              child: Column(
                children: [
                  _PlayDot(),
                  SizedBox(height: 8),
                  Text('Pakai video dari HP aja, gampang',
                      style: SabaTextStyles.sectionTitle),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SabaPrimaryButton(
                label: 'Pilih video',
                onPressed: widget.onGallery == null
                    ? null
                    : () => widget.onGallery!(_parseRefs())),
            const SizedBox(height: 8),
            TextField(
              controller: _refs,
              keyboardType: TextInputType.url,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'Link referensi (opsional, maks 3, pisahkan koma)',
                hintStyle:
                    TextStyle(fontSize: 12, color: SabaColors.muted2),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(12))),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: SabaColors.chipBlueBg,
                  borderRadius: BorderRadius.circular(SabaRadius.card)),
              child: const Text(
                  'Biar mulus: MP4 max 50MB, min 720p, suara jelas ya',
                  style: TextStyle(
                      fontSize: 12, color: SabaColors.body)),
            ),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal')),
          ],
        ),
      ),
    );
  }
}

class _PlayDot extends StatelessWidget {
  const _PlayDot();

  @override
  Widget build(BuildContext context) => SabaIcons.play(size: 64);
}

/// 09 - Langkah 3 Sukses penuh.
class UploadSuccessPage extends StatelessWidget {
  const UploadSuccessPage(
      {super.key,
      required this.jobId,
      required this.onOpen,
      required this.onShare});

  final String jobId;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SabaColors.bgWarm,
      appBar: const SabaHeader(title: 'Upload • Langkah 3/3'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SabaIcons.checkLg(size: 120),
              const SizedBox(height: 16),
              const Text('Terpublish!',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('3/3 Sukses • Lihat artikel • Bagikan',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: SabaColors.muted2)),
              const SizedBox(height: 20),
              SabaPrimaryButton(
                  label: 'Lihat artikel →', onPressed: onOpen),
              TextButton(
                  onPressed: onShare,
                  child: const Text('Bagikan')),
              TextButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((r) => r.isFirst),
                  child: const Text('Kembali ke Beranda')),
            ],
          ),
        ),
      ),
    );
  }
}
