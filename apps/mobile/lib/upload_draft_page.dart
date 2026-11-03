// Langkah 2 Upload ala mockup 08: link referensi, pilih sampul (AI praseleksi),
// edit transkrip, judul, Simpan Draft + Publikasikan. Draft lokal di memori;
// tombol kembali saat ada editan memunculkan opsi Batalkan / Lanjut.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'saba_theme.dart';
import 'saba_widgets.dart';
import 'upload_draft.dart';

class UploadDraftPage extends StatefulWidget {
  const UploadDraftPage({
    super.key,
    required this.jobId,
    required this.apiBase,
    required this.onDone,
    required this.onFail,
    required this.onCancel,
  });

  final String jobId;
  final String apiBase;
  final void Function(String publishJobId) onDone;
  final void Function(String jobId, String error) onFail;
  final VoidCallback onCancel;

  @override
  State<UploadDraftPage> createState() => _UploadDraftPageState();
}

class _UploadDraftPageState extends State<UploadDraftPage> {
  DraftData? _draft;
  String? _error;
  bool _publishing = false;
  bool _cancelled = false;
  bool _allowBackground = false; // publish jalan terus walau halaman ditutup
  bool _savedFlash = false;

  late final TextEditingController _link = TextEditingController();
  late final TextEditingController _transcript = TextEditingController();
  late final TextEditingController _title = TextEditingController();
  List<String> _refs = [];
  int? _tapped;
  int? _coverIndex;
  String _origTranscript = '';
  String _origTitle = '';

  bool get _loading => _draft == null && _error == null;

  @override
  void initState() {
    super.initState();
    _waitDraft();
  }

  @override
  void dispose() {
    _cancelled = true;
    _link.dispose();
    _transcript.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _waitDraft() async {
    final d = await pollDraft(widget.apiBase, widget.jobId,
        alive: () => mounted && !_cancelled);
    if (!mounted || _cancelled) return;
    if (d == null) {
      setState(() => _error = 'Draft tak kunjung siap. Coba lagi.');
      return;
    }
    final aiPick = d.selectedIndices.where((i) => i < d.frames.length);
    setState(() {
      _draft = d;
      _refs = [...d.references];
      _transcript.text = d.transcript;
      _title.text = d.title;
      _origTranscript = d.transcript;
      _origTitle = d.title;
      _coverIndex = d.frames.isEmpty
          ? null
          : aiPick.isEmpty
              ? 0
              : aiPick.first;
      _tapped = _coverIndex;
    });
  }

  /// Ada editan dibanding draft awal?
  bool get _dirty {
    final d = _draft;
    if (d == null) return false;
    if (_transcript.text != _origTranscript) return true;
    if (_title.text != _origTitle) return true;
    if (_coverIndex != null && !_sameCover(d)) return true;
    if (_refs.join('|') != d.references.join('|')) return true;
    return false;
  }

  bool _sameCover(DraftData d) {
    final ai = d.selectedIndices.where((i) => i < d.frames.length);
    final initial = ai.isEmpty ? 0 : ai.first;
    return _coverIndex == initial;
  }

  Future<bool> _confirmBack() async {
    if (!_dirty || _publishing) return true;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan upload?'),
        content: const Text(
            'Editan draft (transkrip, judul, sampul, link) akan hilang.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Batalkan upload',
                  style: TextStyle(color: SabaColors.fail))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop('stay'),
              child: const Text('Lanjut')),
        ],
      ),
    );
    return r != 'stay';
  }

  Future<void> _saveRefs() async {
    final d = _draft;
    if (d == null) return;
    if (_refs.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maksimal 3 link referensi.')));
      return;
    }
    final add = parseRefInput(_link.text)
        .where((u) => !_refs.contains(u))
        .take(3 - _refs.length)
        .toList();
    if (add.isEmpty) return;
    setState(() {
      _refs = [..._refs, ...add];
      _link.clear();
    });
  }

  Future<void> _pasteChip() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = (data?.text ?? '').trim();
    if (t.startsWith('https://') && mounted) {
      setState(() => _link.text = t);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clipboard bukan link https')));
    }
  }

  Future<void> _saveDraft() async {
    final d = _draft;
    if (d == null || _publishing) return;
    final ok = await patchDraft(widget.apiBase, widget.jobId,
        title: _title.text.trim(),
        coverIndex: _coverIndex,
        transcript: _transcript.text,
        references: _refs);
    if (!mounted) return;
    setState(() {
      _savedFlash = ok;
      if (ok) {
        _origTranscript = _transcript.text;
        _origTitle = _title.text.trim();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Draft tersimpan.' : 'Gagal menyimpan draft.')));
    if (ok) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _savedFlash = false);
    }
  }

  Future<void> _publish() async {
    final d = _draft;
    if (d == null || _publishing) return;
    setState(() {
      _publishing = true;
      _error = null;
      _allowBackground = true; // hasil publish tetap diantar walau pop
    });
    bool alive() => !_cancelled || _allowBackground;
    final edited = _transcript.text.trim() != d.transcript.trim();
    final pubId = await publishDraft(widget.apiBase, widget.jobId,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        coverIndex: _coverIndex,
        transcript: _transcript.text,
        references: _refs,
        edited: edited);
    if (!alive()) return;
    if (pubId == null) {
      if (mounted) {
        setState(() {
          _publishing = false;
          _error = 'Gagal mempublikasi. Coba lagi.';
        });
      } else {
        widget.onFail(widget.jobId, 'publish_gagal');
      }
      return;
    }
    final done = await pollArticleDone(widget.apiBase, pubId, alive: alive);
    if (!alive()) return;
    if (done) {
      widget.onDone(pubId);
    } else if (mounted) {
      setState(() {
        _publishing = false;
        _error = 'Artikel tak kunjung jadi. Coba lagi.';
      });
      widget.onFail(widget.jobId, 'timeout');
    } else {
      widget.onFail(widget.jobId, 'timeout');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmBack()) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: SabaColors.bgWarm,
        appBar: const SabaHeader(title: 'Upload'),
        body: _loading
            ? const Center(child: _WaitingBody())
            : _error != null && _draft == null
                ? _ErrorBody(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _waitDraft();
                    },
                    onClose: () => Navigator.of(context).pop(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(SabaSpacing.screen),
                    children: [
                      const SabaStepper(current: 2),
                      const SizedBox(height: SabaSpacing.gapCard),
                      if (_publishing) ...[
                        const SabaCard(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                  child: Text('Mempublikasikan…',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const SizedBox(height: SabaSpacing.gapCard),
                      ],
                      _refsCard(),
                      const SizedBox(height: SabaSpacing.gapCard),
                      _framesCard(),
                      const SizedBox(height: SabaSpacing.gapCard),
                      _editCard(),
                      const SizedBox(height: 8),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12, color: SabaColors.fail)),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: SabaColors.greyFill,
                                foregroundColor: SabaColors.ink,
                              ),
                              onPressed:
                                  _publishing ? null : _saveDraft,
                              child: Text(_savedFlash
                                  ? 'Tersimpan ✓'
                                  : 'Simpan Draft'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _publishing ? null : _publish,
                              child: const Text('Publikasikan →'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
      ),
    );
  }

  Widget _refsCard() {
    return SabaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'Paste link FB / IG di sini…',
              hintStyle:
                  TextStyle(fontSize: 13, color: SabaColors.muted2),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(12))),
              isDense: true,
              filled: true,
              fillColor: SabaColors.greyFill,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _platformChip('Facebook Video'),
              const SizedBox(width: 8),
              _platformChip('Instagram Reels'),
            ],
          ),
          const SizedBox(height: 8),
          SabaPrimaryButton(
              label: 'Simpan Link', onPressed: _saveRefs),
          const SizedBox(height: 8),
          const Text('Link publik aja, maks 3. Cuma buat referensi.',
              style: TextStyle(fontSize: 12, color: SabaColors.muted2)),
          for (final u in _refs)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: SabaColors.chipBlueBg,
                  borderRadius:
                      BorderRadius.circular(SabaRadius.card)),
              child: Row(
                children: [
                  const Text('✓ ',
                      style: TextStyle(
                          fontSize: 12, color: SabaColors.primary)),
                  Expanded(
                    child: Text(
                        '${_shortHost(u)} kepasang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: SabaColors.body)),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _refs = [..._refs]..remove(u)),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text('[x]',
                          style: TextStyle(
                              fontSize: 12,
                              color: SabaColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _platformChip(String label) {
    return Expanded(
      child: GestureDetector(
        onTap: _pasteChip,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: SabaColors.greyFill,
              borderRadius: BorderRadius.circular(SabaRadius.pill)),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SabaColors.body)),
        ),
      ),
    );
  }

  String _shortHost(String u) {
    final uri = Uri.tryParse(u);
    final h = uri?.host.toLowerCase() ?? '';
    final segs =
        (uri?.pathSegments ?? []).where((s) => s.isNotEmpty).toList();
    final slug = segs.isEmpty ? '' : segs.last;
    if (slug.isEmpty) return h;
    return slug.length > 24 ? '${slug.substring(0, 24)}…' : slug;
  }

  Widget _framesCard() {
    final d = _draft!;
    if (d.frames.isEmpty) {
      return const SabaCard(
        child: Text('Frame sampul tak tersedia.',
            style: TextStyle(fontSize: 13, color: SabaColors.muted2)),
      );
    }
    final ai = d.selectedIndices.where((i) => i < d.frames.length).toSet();
    final cover = (_coverIndex != null &&
            _coverIndex! >= 0 &&
            _coverIndex! < d.frames.length)
        ? _coverIndex!
        : 0;
    final tapped = (_tapped != null &&
            _tapped! >= 0 &&
            _tapped! < d.frames.length)
        ? _tapped!
        : cover;
    return SabaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SabaRadius.img),
            child: Image.network(d.frames[cover],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                    height: 200,
                    color: SabaColors.ink,
                    alignment: Alignment.center,
                    child: const Text('SAMPUL',
                        style: TextStyle(color: Colors.white)))),
          ),
          const SizedBox(height: 8),
          const Text('Pilih frame buat sampul',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.frames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _tapped = i),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(SabaRadius.img),
                      child: Image.network(d.frames[i],
                          width: 64,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                              width: 64,
                              height: 72,
                              color: SabaColors.greyFill)),
                    ),
                    if (i == tapped)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  SabaRadius.img),
                              border: Border.all(
                                  color: SabaColors.primary, width: 3)),
                        ),
                      ),
                    if (ai.contains(i))
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                              color: SabaColors.primary,
                              borderRadius: BorderRadius.circular(
                                  SabaRadius.pill)),
                          child: const Text('Pilihan AI',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SabaPrimaryButton(
              label: 'Ambil gambar ini',
              onPressed: () => setState(() => _coverIndex = tapped)),
        ],
      ),
    );
  }

  Widget _editCard() {
    final d = _draft!;
    return SabaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit artikel • ${d.confidenceLabel}',
              style: SabaTextStyles.sectionTitle),
          const SizedBox(height: 8),
          TextField(
            controller: _transcript,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(12))),
              isDense: true,
              filled: true,
              fillColor: SabaColors.chipBlueBg,
            ),
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              prefixText: 'Judul: ',
              prefixStyle:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(12))),
              isDense: true,
              filled: true,
              fillColor: SabaColors.greyFill,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WaitingBody extends StatelessWidget {
  const _WaitingBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SabaStepper(current: 2),
          SizedBox(height: 16),
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3.5),
          ),
          SizedBox(height: 12),
          Text('Menyiapkan draft…',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Mentranskrip suara kreator…',
              style: TextStyle(fontSize: 12, color: SabaColors.muted2)),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody(
      {required this.error, required this.onRetry, required this.onClose});

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: SabaColors.fail),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                  onPressed: onRetry,
                  child: const Text('Coba lagi')),
              const SizedBox(width: 8),
              TextButton(onPressed: onClose, child: const Text('Tutup')),
            ],
          ),
        ],
      ),
    );
  }
}
