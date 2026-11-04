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
import 'upload_draft_page.dart';
import 'upload.dart';
import 'vote.dart';

// 10.0.2.2 = host machine localhost as seen from the Android emulator.
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

class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with WidgetsBindingObserver {
  bool _busy = false;
  double _uploadPct = 0; // 0..1, progres real kirim video (Blok A: honest %).
  List<FeedArticle> _feed = [];
  bool _feedLoading = true;
  int _navIndex = 0;

  bool _foreground = true; // false = info notification only when a job finishes in background.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onNotifTap = (payload) async {
      if (payload != null) _openArticle(payload);
    };
    _loadFeed();
  }

  /// Load the home article feed. Failure = empty feed (empty state speaks).
  /// Parallel (not serial) to meet the <2s feed requirement.
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

  /// Feed shown as-is (server order); filter/search moved to Explore.
  List<FeedArticle> _visibleFeed() => _feed;

  /// Top 3 by votes for the trending section.
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
      const SnackBar(content: Text('Coming soon — only Home is ready')),
    );
  }

  /// Video upload sheet: Step 1 Source (gallery), article cooked automatically.
  void _openConvertSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => UploadSourceSheet(
        onGallery: _busy
            ? null
            : () {
                Navigator.of(ctx).pop();
                _uploadFromGallery();
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

  // Background/foreground: info notification only when a job finishes in background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  /// Upload a video from the gallery, then open Step 2 (draft).
  /// Used by FAB + Profile page + Inbox (retry).
  Future<void> _uploadFromGallery() async {
    if (_busy) return;
    setState(() {
      _navIndex = 0;
      _busy = true;
      _uploadPct = 0;
    });
    JobRecord? record;
    try {
      final jobId = await uploadVideo(
        apiBase: apiBase,
        creator: ProfileStore.name.isNotEmpty ? ProfileStore.name : null,
        onProgress: (p) {
          if (record != null) JobHistory.progress(record.id, p);
          if (!mounted) return;
          // Light throttle: setState per callback but cheap (one bar).
          setState(() => _uploadPct = p.clamp(0.0, 1.0));
        },
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload cancelled.')));
        return;
      }
      record = JobHistory.add(jobId, 'Video from gallery');
      _openDraft(jobId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')));
    }
  }

  /// Mockup-style Step 2/3: full draft page (links, cover, transcript).
  void _openDraft(String jobId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadDraftPage(
          jobId: jobId,
          apiBase: apiBase,
          onDone: (publishJobId) {
            JobHistory.done(jobId);
            if (!_foreground) {
              notifyJob('Article ready', publishJobId,
                  payload: publishJobId);
            }
            _loadFeed();
            _openSuccess(publishJobId);
          },
          onFail: (failedId, error) {
            JobHistory.fail(failedId, error);
            if (!_foreground) {
              notifyJob('Job $failedId failed', error);
            }
          },
          onCancel: () => JobHistory.fail(jobId, 'cancelled'),
        ),
      ),
    );
  }

  /// Mockup-style Step 3/3: full success page.
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

  /// WA/X/FB/TG/copy share sheet (replaces direct copy).
  Future<void> _copyArticle(String jobId) async {
    if (!mounted) return;
    final title =
        _feed.where((a) => a.id == jobId).map((a) => a.title).firstOrNull ??
            'SABA article';
    await showShareSheet(context,
        url: '$webBase/article/$jobId', title: title);
  }

  /// Native article detail inside the app.
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
              const Text('HOTTEST TOPICS RIGHT NOW',
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
                    Text('See All',
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
                              '${compactVotes(baseVotes(top[i].id))} popularity • ${top[i].brand.isNotEmpty ? top[i].brand : 'review'}',
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

  /// Mockup-style post card: author, title, serif quote, photo + caption,
  /// tag chip, combined action bar.
  Widget _forumCard(FeedArticle a) {
    final handle = a.brand.isNotEmpty ? '@${a.brand}' : '@review';
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
                            ? '$handle  •  published by ${a.creator}'
                            : handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                        'Product review • ${timeAgo(a.createdAt).isEmpty ? 'just now' : timeAgo(a.createdAt)}',
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
                            Text('Gallery',
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
            if (_busy)
              Container(
                width: double.infinity,
                color: Colors.white,
                padding:
                    const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: SabaStageCard(
                  pct: (_uploadPct * 100).floor(),
                  line1: 'Your video is uploading now.',
                  line2: 'Now sending your video to the server',
                  line3: 'Hang tight – almost there…',
                  footer:
                      'Uploading ${(_uploadPct * 100).floor()}% – please don’t close this page',
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
                            '1. Tap + then pick a video from the gallery\n'
                            '2. Wait for the notification — the article is cooked on the server\n'
                            '3. Open and read the article inside this app',
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
                      icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
                      label: 'Explore'),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
                                    label: 'Inbox'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
                                    label: 'Profile'),
        ],
      );
  }
}

