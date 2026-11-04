// Step 2 Upload per mockup 08: reference links, cover pick (AI preselected),
// transcript edit, title, Save Draft + Publish. Draft lives in memory;
// the back button with unsaved edits offers Cancel vs Keep editing.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'saba_theme.dart';
import 'saba_widgets.dart';
import 'social_handle.dart';
import 'upload.dart';
import 'upload_draft.dart';

class UploadDraftPage extends StatefulWidget {
  const UploadDraftPage({
    super.key,
    this.jobId,
    this.uploadFile,
    this.creator,
    required this.apiBase,
    required this.onDone,
    required this.onFail,
    required this.onCancel,
  }) : assert(jobId != null || uploadFile != null);

  /// Server job id. Null when [uploadFile] is given (upload runs in-page).
  final String? jobId;

  /// Pre-picked video to upload in-page, so 7b opens instantly with real %.
  final File? uploadFile;

  final String? creator;
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
  String? _jobId; // real job id (widget.jobId or from the in-page upload)
  JobRecord? _record;
  double? _uploadPct; // null = not uploading (polling draft instead)

  late final TextEditingController _link = TextEditingController();
  late final TextEditingController _transcript = TextEditingController();
  late final TextEditingController _title = TextEditingController();
  List<String> _refs = [];
  final _handles = <String, SocialHandle?>{};
  int? _tapped;
  int? _coverIndex;
  String _origTranscript = '';
  String _origTitle = '';

  bool get _loading => _draft == null && _error == null;

  @override
  void initState() {
    super.initState();
    if (widget.uploadFile != null) {
      _startUpload();
    } else {
      _jobId = widget.jobId;
      _waitDraft();
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _link.dispose();
    _transcript.dispose();
    _title.dispose();
    super.dispose();
  }

  /// Upload the pre-picked file with real progress, then poll the draft.
  /// 7b is already on screen, so the 7 -> 7b hop is instant.
  Future<void> _startUpload() async {
    final file = widget.uploadFile!;
    setState(() => _uploadPct = 0);
    try {
      final id = await uploadFileData(
        file: file,
        apiBase: widget.apiBase,
        creator: widget.creator,
        onProgress: (p) {
          if (mounted && !_cancelled) setState(() => _uploadPct = p);
        },
      );
      if (!mounted || _cancelled) return;
      if (id == null) {
        setState(() {
          _uploadPct = null;
          _error = 'Upload cancelled.';
        });
        return;
      }
      _record = JobHistory.add(id, 'Video from gallery');
      setState(() {
        _jobId = id;
        _uploadPct = null;
      });
      _waitDraft();
    } catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _uploadPct = null;
        _error = 'Upload failed: $e';
      });
    }
  }

  Future<void> _waitDraft() async {
    final jobId = _jobId;
    if (jobId == null) return;
    final d = await pollDraft(widget.apiBase, jobId,
        alive: () => mounted && !_cancelled);
    if (!mounted || _cancelled) return;
    if (d == null) {
      setState(() => _error = 'Draft is taking too long. Try again.');
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
    for (final u in _refs) {
      lookupSocialHandle(u, cache: _handles).then((h) {
        if (mounted && h != null) setState(() {});
      });
    }
  }

  /// Any edits compared to the loaded draft?
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
        title: const Text('Cancel upload?'),
        content: const Text(
            'Draft edits (transcript, title, cover, links) will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel upload',
                  style: TextStyle(color: SabaColors.fail))),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop('stay'),
              child: const Text('Keep editing')),
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
          content: Text('Maximum 3 reference links.')));
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
    // Best-effort: read the creator @handle (YouTube/TikTok via oEmbed).
    for (final u in add) {
      lookupSocialHandle(u, cache: _handles).then((h) {
        if (mounted && h != null) setState(() {});
      });
    }
  }

  Future<void> _pasteChip() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = (data?.text ?? '').trim();
    if (t.startsWith('https://') && mounted) {
      setState(() => _link.text = t);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Clipboard is not an https link')));
    }
  }

  Future<void> _saveDraft() async {
    final d = _draft;
    if (d == null || _publishing) return;
    final ok = await patchDraft(widget.apiBase, _jobId!,
        title: _title.text.trim(),
        coverIndex: _coverIndex,
        transcript: _transcript.text,
        references: _refs);
    if (!mounted) return;
    setState(() {
      _savedFlash = ok; // ("Saved ✓" indicator)
      if (ok) {
        _origTranscript = _transcript.text;
        _origTitle = _title.text.trim();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Draft saved.' : 'Failed to save draft.')));
    if (ok) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _savedFlash = false);
    }
  }

  Future<void> _publish() async {
    final d = _draft;
    final jobId = _jobId;
    if (d == null || jobId == null || _publishing) return;
    setState(() {
      _publishing = true;
      _error = null;
      _allowBackground = true; // hasil publish tetap diantar walau pop
    });
    bool alive() => !_cancelled || _allowBackground;
    final edited = _transcript.text.trim() != d.transcript.trim();
    final pubId = await publishDraft(widget.apiBase, jobId,
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
          _error = 'Failed to publish. Try again.';
        });
      } else {
        widget.onFail(jobId, 'publish_gagal');
      }
      return;
    }
    final done = await pollArticleDone(widget.apiBase, pubId, alive: alive);
    if (!alive()) return;
    if (done) {
      final r = _record;
      if (r != null) JobHistory.done(r.id);
      widget.onDone(pubId);
    } else if (mounted) {
      setState(() {
        _publishing = false;
        _error = 'Article is taking too long. Try again.';
      });
      widget.onFail(jobId, 'timeout');
    } else {
      widget.onFail(jobId, 'timeout');
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
            ? _WaitingBody(
                uploadPct: _uploadPct == null
                    ? null
                    : (_uploadPct! * 100).round().clamp(0, 100),
                onCancel: () {
                  _cancelled = true;
                  final r = _record;
                  if (r != null) JobHistory.fail(r.id, 'cancelled');
                  widget.onCancel();
                  Navigator.of(context).pop();
                },
              )
            : _error != null && _draft == null
                ? _ErrorBody(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      if (_jobId == null && widget.uploadFile != null) {
                        _cancelled = false;
                        _startUpload();
                      } else {
                        _waitDraft();
                      }
                    },
                    onClose: () => Navigator.of(context).pop(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(SabaSpacing.screen),
                    children: [
                      const SabaStepper(current: 2),
                      const SizedBox(height: SabaSpacing.gapCard),
                    if (_publishing) ...[
                      const SabaStageCard(
                        pct: null,
                        line1: 'The AI agents are working now.',
                        line2: 'Now publishing your article',
                        line3: 'Preparing your share link…',
                        footer:
                            'Publishing your article… – please don’t close this page',
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
                                  ? 'Saved ✓'
                                  : 'Save Draft'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _publishing ? null : _publish,
                              child: const Text('Publish →'),
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
              hintText: 'Paste FB / IG link here…',
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
              label: 'Save Link', onPressed: _saveRefs),
          const SizedBox(height: 8),
          const Text('Public links only, max 3. For reference only.',
              style: TextStyle(fontSize: 12, color: SabaColors.muted2)),
          for (final u in _refs)
            Builder(builder: (context) {
              final h = _handles[u];
              final label = h != null ? '${h.handle} attached' : '${_shortHost(u)} attached';
              return Container(
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
                    child: Text(label,
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
              );
            }),
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
        child: Text('No cover frame available.',
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
                    child: const Text('COVER',
                        style: TextStyle(color: Colors.white)))),
          ),
          const SizedBox(height: 8),
          const Text('Pick a frame for the cover',
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
                          child: const Text('AI pick',
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
              label: 'Use this image',
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
          Text('Edit article • ${d.confidenceLabel}',
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
              prefixText: 'Title: ',
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

/// 07b - Upload Progress Transcript: big % + staged status lines + bar.
/// Pct is display-only (draft polling has no server progress), capped at 92
/// until the draft arrives — the bar never claims 100% before it is real.
class _WaitingBody extends StatefulWidget {
  const _WaitingBody({required this.onCancel, this.uploadPct});

  final VoidCallback onCancel;

  /// 0..100 real upload progress. Null = polling draft.
  /// Displayed as the first 10% of one continuous bar (see continuousPct).
  final int? uploadPct;

  @override
  State<_WaitingBody> createState() => _WaitingBodyState();
}

class _WaitingBodyState extends State<_WaitingBody> {
  static const _cap = 92;
  int _pct = 0;
  bool _alt = false;
  Timer? _t;
  Timer? _altT;

  @override
  void initState() {
    super.initState();
    // Gentle tick (1s): fake progress only, keeps GPU churn low.
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _pct >= _cap) {
        _t?.cancel();
        return;
      }
      setState(() => _pct = (_pct + 7).clamp(0, _cap));
    });
    // Alternate the two status lines every 2.5s.
    _altT = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() => _alt = !_alt);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _altT?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One continuous bar: upload fills 0..10, draft polling 10..90.
    final uploading = widget.uploadPct != null;
    final pct =
        continuousPct(uploadPct: widget.uploadPct, draftPct: _pct);
    return ListView(
      padding: const EdgeInsets.all(SabaSpacing.screen),
      children: [
        const SabaCard(child: SabaStepper(current: 2)),
        const SizedBox(height: SabaSpacing.gapCard),
        SabaStageCard(
          pct: pct,
          line1: uploading
              ? 'Uploading your video…'
              : 'The AI agents are working now.',
          footer: uploading
              ? 'Uploading ${widget.uploadPct}% – please don’t close this page'
              : 'Transcribing $pct% – please don’t close this page',
          middle: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              _alt
                  ? 'Capturing your important scenes…'
                  : 'Now transcribing your video into text',
              key: ValueKey(_alt),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SabaColors.primary),
            ),
          ),
        ),
        const SizedBox(height: SabaSpacing.gapCard),
        SizedBox(
          width: double.infinity,
          height: SabaSpacing.btnH,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: const BorderSide(color: SabaColors.borderSoft),
              backgroundColor: Colors.white,
            ),
            onPressed: widget.onCancel,
            child: const Text('Cancel',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
          ),
        ),
      ],
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
    return Center(
      child: Padding(
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
                    child: const Text('Try again')),
                const SizedBox(width: 8),
                TextButton(onPressed: onClose, child: const Text('Close')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
