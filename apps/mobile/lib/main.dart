import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'article_detail.dart';
import 'edit_profile_page.dart';
import 'feed.dart';
import 'login_page.dart';
import 'notify.dart';
import 'profile.dart';
import 'saba_screens.dart';
import 'saba_theme.dart';
import 'saba_widgets.dart';
import 'share.dart';
import 'upload.dart';
import 'vote.dart';

// 10.0.2.2 = localhost mesin host dari Android emulator.
// Override: flutter run --dart-define=API_BASE=https://api.example.com
//   --dart-define=WEB_BASE=https://web.example.com
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:4301',
);
const webBase = String.fromEnvironment(
  'WEB_BASE',
  defaultValue: 'http://10.0.2.2:4320',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotif();
  runApp(const SabaApp());
}

class SabaApp extends StatelessWidget {
  const SabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SABA',
      theme: sabaTheme(),
      home: const SplashScreen(child: SharePage()),
    );
  }
}

/// Satu job convert aktif (polling). Riwayat kini diganti feed artikel.
class JobEntry {
  JobEntry({required this.jobId, required this.url});

  final String jobId;
  final String url;
  String status = 'processing'; // processing | done | failed
  String? error;
}

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with WidgetsBindingObserver {
  String _status = 'Pilih video dari galeri untuk mulai.';
  String? _doneJobId;
  bool _busy = false;
  String? _error;
  List<FeedArticle> _feed = [];
  bool _feedLoading = true;
  int _navIndex = 0;

  int _pollSeq = 0; // token poll aktif; poll lama berhenti saat tersalip/cancel.
  bool _foreground = true; // false = notifikasi info saat job selesai.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onNotifTap = (payload) async {
      if (payload != null) _openArticle(payload);
    };
    _loadFeed();
  }

  /// Muat feed artikel untuk home. Gagal = feed kosong (status card bicara).
  /// Paralel (bukan serial) agar memenuhi AC feed <2 dtk.
  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() => _feedLoading = true);
    try {
      final ids = await fetchFeedIds(apiBase);
      final out = (await Future.wait(
        ids.map((id) => fetchFeedArticle(apiBase, id)),
      ))
          .whereType<FeedArticle>()
          .toList();
      if (!mounted) return;
      setState(() {
        _feed = out;
        _feedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedLoading = false);
    }
  }

  /// Feed tampil apa adanya (urutan server); filter/search pindah ke Jelajah.
  List<FeedArticle> _visibleFeed() => _feed;

  /// 3 teratas by votes untuk seksi trending.
  List<FeedArticle> _trending() {
    final list = [..._feed]
      ..sort((a, b) => baseVotes(b.id).compareTo(baseVotes(a.id)));
    return list.take(3).toList();
  }

  void _onNav(int i) {
    if (i == 0 || i == 1 || i == 2 || i == 3) {
      setState(() => _navIndex = i);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Segera hadir — baru Beranda yang jadi')),
    );
  }

  /// Sheet upload video: Langkah 1 Sumber (galeri), artikel dimasak otomatis.
  void _openConvertSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => UploadSourceSheet(
        onGallery: _busy
            ? null
            : (refs) {
                Navigator.of(ctx).pop();
                _uploadFromGallery(refs);
              },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    onNotifTap = null;
    super.dispose();
  }

  // Background/foreground: notifikasi info hanya saat job selesai di background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  /// Upload video dari galeri lalu lacak sampai artikel jadi.
  /// Dipakai FAB + halaman Profil. refs: link referensi opsional (maks 3).
  Future<void> _uploadFromGallery([List<String> refs = const []]) async {
    if (_busy) return;
    setState(() {
      _navIndex = 0;
      _busy = true;
      _error = null;
      _doneJobId = null;
      _status = 'Memilih video…';
    });
    final seq = ++_pollSeq;
    var lastPct = -1;
    JobRecord? record;
    try {
      final jobId = await uploadVideo(
        apiBase: apiBase,
        creator: ProfileStore.name.isNotEmpty ? ProfileStore.name : null,
        references: refs,
        onProgress: (p) {
          if (record != null) JobHistory.progress(record.id, p);
          final pct = (p * 100).floor();
          if (pct >= lastPct + 5 && mounted && seq == _pollSeq) {
            lastPct = pct;
            setState(() => _status = 'Mengunggah video… $pct%');
          }
        },
      );
      if (jobId == null) {
        if (!mounted || seq != _pollSeq) return;
        _set('Upload dibatalkan.');
        return;
      }
      record = JobHistory.add(jobId, 'Video dari galeri');
      await _trackJob(jobId, seq, label: 'Video dari galeri');
    } catch (e) {
      if (!mounted || seq != _pollSeq) return;
      _set('Gagal: $e', isError: true);
    }
  }

  /// Poll jobId sampai artikel jadi.
  Future<void> _trackJob(String jobId, int seq, {required String label}) async {
    final entry = JobEntry(jobId: jobId, url: label);
    setState(() => _status = 'Job dibuat: $jobId — menunggu artikel...');
    await _pollArticle(entry, seq);
    if (!mounted || seq != _pollSeq) return; // tersalip job baru/cancel.
    if (entry.status == 'done') {
      JobHistory.done(jobId);
    } else {
      JobHistory.fail(jobId, entry.error ?? 'gagal');
    }
    setState(() {
      if (entry.status == 'done') {
        _doneJobId = jobId;
        _status = 'Artikel jadi: $jobId';
      } else {
        _error = entry.error;
        _status = 'Job $jobId gagal: ${entry.error}';
      }
      _busy = false;
    });
    // Info di background saja; di foreground user sudah melihat status card.
    if (!_foreground) {
      if (entry.status == 'done') {
        await notifyJob('Artikel jadi', jobId, payload: jobId);
      } else {
        await notifyJob('Job $jobId gagal', entry.error ?? 'unknown');
      }
    }
    if (entry.status == 'done') {
      _loadFeed();
      _openSuccess(jobId);
    }
  }

  /// Langkah 3/3 ala mockup: halaman sukses penuh.
  void _openSuccess(String jobId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadSuccessPage(
          jobId: jobId,
          onOpen: () {
            Navigator.of(context).pop();
            _openArticle(jobId);
          },
          onShare: () => _copyArticle(jobId),
        ),
      ),
    );
  }

  /// Poll `GET /v1/articles/<jobId>` sampai 200 (maks ~10 menit).
  /// Berhenti saat `seq` tersalip (job baru/cancel): entry ditandai dibatalkan.
  Future<void> _pollArticle(JobEntry entry, int seq) async {
    for (var i = 0; i < 120; i++) {
      if (!mounted || seq != _pollSeq) {
        if (entry.status == 'processing') {
          entry
            ..status = 'failed'
            ..error = 'dibatalkan';
        }
        return;
      }
      try {
        if (await fetchArticle(entry.jobId)) {
          entry.status = 'done';
          return;
        }
      } catch (_) {
        // Jaringan sempat putus: coba lagi sampai batas poll.
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    entry
      ..status = 'failed'
      ..error = 'timeout: artikel belum jadi setelah 10 menit';
  }

  void _set(String status, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status;
      _error = isError ? status : null;
    });
  }

  /// Sheet share WA/X/FB/TG/salin (ganti salin langsung).
  Future<void> _copyArticle(String jobId) async {
    if (!mounted) return;
    final title =
        _feed.where((a) => a.id == jobId).map((a) => a.title).firstOrNull ??
            'Artikel SABA';
    await showShareSheet(context,
        url: '$webBase/article/$jobId', title: title);
  }

  /// Detail artikel native di dalam app.
  Future<void> _openArticle(String jobId) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              ArticleDetailPage(jobId: jobId, apiBase: apiBase, webBase: webBase)),
    );
  }

  Color get _bg => SabaColors.bgCool;

  Widget _trendingCard() {
    final top = _trending();
    if (top.isEmpty) return const SizedBox();
    const rankColors = [Color(0xFFFF5A00), Colors.amber, SabaColors.muted2];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SabaRadius.card),
          border: Border.all(color: SabaColors.borderCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFF5A00), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('TOPIK PALING RAMAI SAAT INI',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => _onNav(1),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lihat Semua',
                        style: TextStyle(fontSize: 11, color: sabaBlue)),
                    Icon(Icons.chevron_right,
                        size: 14, color: sabaBlue),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: SabaColors.greyFill),
          for (var i = 0; i < top.length; i++)
            GestureDetector(
              onTap: () => _openArticle(top[i].id),
              child: Padding(
                padding: EdgeInsets.only(bottom: i < top.length - 1 ? 10 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text('${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: rankColors[i])),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(top[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                              '${compactVotes(baseVotes(top[i].id))} popularitas • ${top[i].brand.isNotEmpty ? top[i].brand : 'ulasan'}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: SabaColors.muted2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Kartu post ala mockup: author, judul, kutipan serif, foto + caption,
  /// chip tag, bar aksi gabungan.
  Widget _forumCard(FeedArticle a) {
    final handle = a.brand.isNotEmpty ? '@${a.brand}' : '@ulasan';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SabaRadius.card),
          border: Border.all(color: SabaColors.borderCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: SabaColors.greyFill,
                child: Text(
                    (a.brand.isNotEmpty ? a.brand : 'S')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SabaColors.muted2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        a.creator.isNotEmpty
                            ? '$handle  •  diterbitkan oleh ${a.creator}'
                            : handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                        'Ulasan produk • ${timeAgo(a.createdAt).isEmpty ? 'baru saja' : timeAgo(a.createdAt)}',
                        style: const TextStyle(
                            fontSize: 10, color: SabaColors.muted2)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _copyArticle(a.id),
                child: const Icon(Icons.more_horiz,
                    size: 18, color: SabaColors.muted2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openArticle(a.id),
            child: Text(a.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, height: 1.35)),
          ),
          if (a.excerpt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(a.excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: SabaTextStyles.excerpt
                    .copyWith(fontSize: 13, height: 1.6)),
          ],
          if (a.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openArticle(a.id),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SabaRadius.img),
                    child: Image.network(a.images.first,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                  if (a.images.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius:
                                BorderRadius.circular(SabaRadius.pill)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library,
                                size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Galeri',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                        a.brand.isNotEmpty ? a.brand : 'SABA Original',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black87),
                            ])),
                  ),
                ],
              ),
            ),
          ],
          if (a.brand.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(SabaRadius.pill),
                      border:
                          Border.all(color: SabaColors.borderSoft)),
                  child: Text('#${a.brand}',
                      style: const TextStyle(
                          fontSize: 11, color: SabaColors.body)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          VoteBar(
            articleId: a.id,
            onOpen: () => _openArticle(a.id),
            onShare: () => _copyArticle(a.id),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_navIndex == 1) {
      return Scaffold(
        body: JelajahPage(feed: _feed, onOpen: _openArticle),
        floatingActionButton: FloatingActionButton(
          onPressed: _openConvertSheet,
          backgroundColor: sabaBlue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: _navBar(),
      );
    }
    if (_navIndex == 2) {
      return Scaffold(
        body: InboxPage(
          jobs: JobHistory.records,
          onOpen: _openArticle,
          onRetry: _uploadFromGallery,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openConvertSheet,
          backgroundColor: sabaBlue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: _navBar(),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      body: _navIndex == 3
          ? ProfilePage(
              feed: _feed,
              onEdit: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const EditProfilePage()),
              ),
              onLogin: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const LoginPage()),
              ),
              onUpload: _uploadFromGallery,
              onOpenArticle: _openArticle,
            )
          : SafeArea(
              child: Column(
          children: [
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: Text('SABA',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _onNav(1),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: SabaColors.greyFill,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.search,
                          size: 18, color: SabaColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy || _error != null || _doneJobId != null)
              Container(
                width: double.infinity,
                color: Colors.white,
                padding:
                    const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _ConvertStatus(
                  busy: _busy,
                  error: _error,
                  status: _status,
                  doneJobId: _doneJobId,
                  onCancel: () => setState(() => _pollSeq++),
                  onRetry: () {
                    setState(() => _error = null);
                    _uploadFromGallery();
                  },
                  onDismiss: () => setState(() {
                    _error = null;
                    _doneJobId = null;
                  }),
                  onOpen: () => _openArticle(_doneJobId!),
                  onCopy: () => _copyArticle(_doneJobId!),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _trendingCard(),
                  const SizedBox(height: 12),
                  if (_feedLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child:
                              CircularProgressIndicator()),
                    )
                  else if (_visibleFeed().isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.colorScheme
                                  .primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(
                                      20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'S',
                              style: theme
                                  .textTheme.headlineMedium
                                  ?.copyWith(
                                color: theme.colorScheme
                                    .onPrimaryContainer,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Ketuk + lalu pilih video dari galeri\n'
                            '2. Tunggu notifikasi — artikel dimasak di server\n'
                            '3. Buka dan baca artikel di dalam app ini',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(
                              color: theme
                                  .colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final a in _visibleFeed()) ...[
                      _forumCard(a),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openConvertSheet,
        backgroundColor: sabaBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: _navBar(),
    );
  }

  BottomNavigationBar _navBar() {
    return BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: _onNav,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: sabaBlue,
        unselectedItemColor: SabaColors.muted2,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              label: 'Jelajah'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Kotak Masuk'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profil'),
        ],
      );
  }
}

/// Kartu status convert: sibuk (langkah animasi + spinner) / gagal / jadi.
/// Gaya disamakan kartu feed: putih, radius 16, border #E4E6EB.
class _ConvertStatus extends StatelessWidget {
  const _ConvertStatus({
    required this.busy,
    required this.error,
    required this.status,
    required this.doneJobId,
    required this.onCancel,
    required this.onRetry,
    required this.onDismiss,
    required this.onOpen,
    required this.onCopy,
  });

  final bool busy;
  final String? error;
  final String status;
  final String? doneJobId;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isError = error != null;
    return Container(
      padding: const EdgeInsets.all(SabaSpacing.cardPad),
      decoration: BoxDecoration(
          color: isError ? SabaColors.failBg : Colors.white,
          borderRadius: BorderRadius.circular(SabaRadius.card),
          border: Border.all(
              color: isError
                  ? SabaColors.fail
                  : SabaColors.borderSoft)),
      child: busy
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SabaStepper(current: 2),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        strokeCap: StrokeCap.round,
                        color: sabaBlue,
                        backgroundColor: SabaColors.greyFill,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: _StepCycler()),
                    IconButton(
                      tooltip: 'Batal',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      color: SabaColors.muted2,
                      onPressed: onCancel,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Langkah 3 Sukses: ikon check handoff; gagal: ikon error fail.
                if (isError)
                  const Icon(Icons.error_outline,
                      color: SabaColors.fail)
                else
                  SabaIcons.check(size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isError
                              ? 'Gagal membuat artikel'
                              : 'Artikel jadi!',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(isError ? error! : status,
                          style: const TextStyle(
                              fontSize: 12,
                              color: SabaColors.muted2)),
                      const SizedBox(height: 10),
                      if (isError)
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh,
                                  size: 16),
                              label: const Text('Coba lagi'),
                            ),
                            TextButton(
                                onPressed: onDismiss,
                                child: const Text('Tutup')),
                          ],
                        )
                      else
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: onOpen,
                              icon: const Icon(Icons.open_in_new,
                                  size: 16),
                              label: const Text('Baca'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: onCopy,
                              icon: const Icon(Icons.copy,
                                  size: 16),
                              label:
                                  const Text('Salin link'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Teks langkah bergilir selagi menunggu (indeterminate, kosmetik):
/// unduh → transkrip → tulis. Status teknis tetap di subtitle pemanggil.
class _StepCycler extends StatefulWidget {
  const _StepCycler();

  @override
  State<_StepCycler> createState() => _StepCyclerState();
}

class _StepCyclerState extends State<_StepCycler> {
  static const _steps = [
    'Mengunduh video…',
    'Mentranskrip suara kreator…',
    'Menulis artikel SEO…',
  ];
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(_steps[_i],
              key: ValueKey(_i),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var s = 0; s < _steps.length; s++)
              Container(
                margin: EdgeInsets.only(
                    right: s < _steps.length - 1 ? 4 : 0),
                width: 16,
                height: 4,
                decoration: BoxDecoration(
                    color: s <= _i
                        ? sabaBlue
                        : SabaColors.borderSoft,
                    borderRadius: BorderRadius.circular(999)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Biasanya 3–5 menit, jangan tutup app ini.',
            style: TextStyle(fontSize: 11, color: SabaColors.muted2)),
      ],
    );
  }
}

/// `GET /v1/articles/<jobId>` → true jika 200 (artikel jadi).
Future<bool> fetchArticle(String jobId) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('$apiBase/v1/articles/$jobId'))
        .timeout(const Duration(seconds: 20));
    final res = await req.close().timeout(const Duration(seconds: 20));
    await res.transform(utf8.decoder).join();
    return res.statusCode == 200;
  } finally {
    client.close();
  }
}
