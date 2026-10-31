// Vote ala forum: chip "Setuju" + downvote, murni lokal (tanpa backend).
// Micro-interaction: pop elastis 0.92 -> 1.08 -> 1, toggle biru solid,
// counter +1, badge +1 melayang + ring burst, downvote press scale.
import 'package:flutter/material.dart';

const zhihuBlue = Color(0xFF0084FF);

/// Store in-memory per sesi agar feed + detail konsisten.
class VoteStore {
  static final Set<String> upvoted = {};
  static final Set<String> downvoted = {};

  static void toggleUp(String id) {
    if (upvoted.contains(id)) {
      upvoted.remove(id);
    } else {
      upvoted.add(id);
      downvoted.remove(id);
    }
  }

  static void toggleDown(String id) {
    if (downvoted.contains(id)) {
      downvoted.remove(id);
    } else {
      downvoted.add(id);
      upvoted.remove(id);
    }
  }
}

/// Angka dasar stabil per artikel agar demo terasa hidup.
int baseVotes(String id) => 100 + (id.hashCode.abs() % 2000);

String compactVotes(int n) {
  if (n >= 1000) {
    final v = n / 1000;
    final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '${s.replaceAll('.0', '')}k';
  }
  return '$n';
}

String exactVotes(int n) {
  final s = '$n';
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class VotePill extends StatefulWidget {
  const VotePill({super.key, required this.articleId, this.compact = false});

  final String articleId;
  final bool compact;

  @override
  State<VotePill> createState() => _VotePillState();
}

class _VotePillState extends State<VotePill>
    with TickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;
  late final AnimationController _float;
  late final Animation<double> _floatY;
  late final Animation<double> _floatOpacity;
  late final Animation<double> _ring;
  bool _showFx = false;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.92)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.92, end: 1.08)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.08, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
    ]).animate(_pop);
    _float = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _floatY = Tween(begin: 0.0, end: -32.0).animate(
        CurvedAnimation(parent: _float, curve: Curves.easeOut));
    _floatOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 0.0), weight: 30),
    ]).animate(_float);
    _ring = Tween(begin: 0.4, end: 1.7).animate(
        CurvedAnimation(parent: _float, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pop.dispose();
    _float.dispose();
    super.dispose();
  }

  void _onTap() {
    final wasActive = VoteStore.upvoted.contains(widget.articleId);
    setState(() => VoteStore.toggleUp(widget.articleId));
    _pop.forward(from: 0);
    if (!wasActive) {
      setState(() => _showFx = true);
      _float.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _showFx = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = VoteStore.upvoted.contains(widget.articleId);
    final base = baseVotes(widget.articleId);
    final label = active ? exactVotes(base + 1) : compactVotes(base);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTap: _onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 10 : 12,
                  vertical: widget.compact ? 5 : 6),
              decoration: BoxDecoration(
                color: active ? zhihuBlue : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: active
                        ? zhihuBlue
                        : zhihuBlue.withValues(alpha: 0.3)),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: zhihuBlue.withValues(alpha: 0.42),
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward_rounded,
                      size: 14,
                      color: active ? Colors.white : zhihuBlue),
                  const SizedBox(width: 4),
                  Text('Setuju $label',
                      style: TextStyle(
                          fontSize: 12,
                          color: active ? Colors.white : zhihuBlue,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
        if (_showFx) ...[
          AnimatedBuilder(
            animation: _float,
            builder: (context, _) => Positioned(
              top: _floatY.value,
              left: 20,
              child: Opacity(
                opacity: _floatOpacity.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: zhihuBlue.withValues(alpha: 0.3)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 2))
                      ]),
                  child: const Text('+1',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: zhihuBlue)),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _float,
            builder: (context, _) => Positioned(
              top: 12,
              left: 24,
              child: Opacity(
                opacity: 1 - _float.value,
                child: Transform.scale(
                  scale: _ring.value,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: zhihuBlue, width: 2)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class VoteDown extends StatefulWidget {
  const VoteDown({super.key, required this.articleId});

  final String articleId;

  @override
  State<VoteDown> createState() => _VoteDownState();
}

class _VoteDownState extends State<VoteDown> {
  double _press = 1.0;

  @override
  Widget build(BuildContext context) {
    final active = VoteStore.downvoted.contains(widget.articleId);
    return GestureDetector(
      onTapDown: (_) => setState(() => _press = 0.9),
      onTapUp: (_) => setState(() => _press = 1.0),
      onTapCancel: () => setState(() => _press = 1.0),
      onTap: () => setState(() => VoteStore.toggleDown(widget.articleId)),
      child: AnimatedScale(
        scale: _press,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFEFF6FF),
            shape: BoxShape.circle,
            border: Border.all(
                color: active
                    ? const Color(0xFFCBD5E1)
                    : zhihuBlue.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.arrow_downward_rounded,
              size: 14,
              color: active
                  ? const Color(0xFF475569)
                  : zhihuBlue),
        ),
      ),
    );
  }
}
