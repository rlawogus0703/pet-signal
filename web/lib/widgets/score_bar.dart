import 'package:flutter/material.dart';

import '../matching/explain.dart';
import '../models/score_breakdown.dart';
import '../theme/app_theme.dart';


class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.item, this.delay = Duration.zero, this.labelWidth = 104, this.color});
  final ScoreItem item;
  final Duration delay;
  final double labelWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = item.value;
    final color = this.color ?? (item.ai ? const Color(0xFF6366F1) : AppColors.score(v ?? 0));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: AppColors.subtext),
          const SizedBox(width: 8),
          SizedBox(
            width: labelWidth,
            child: Row(
              children: [
                Flexible(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                if (item.ai) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration:
                        BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(4)),
                    child: const Text('AI',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: v == null && item.note != null
                ? Text(item.note!, style: const TextStyle(fontSize: 12, color: AppColors.subtext))
                : _DelayedBar(value: v ?? 0, color: color, delay: delay),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 34,
            child: Text(v == null ? '-' : '${(v * 100).round()}',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w800, color: v == null ? AppColors.subtext : AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class _DelayedBar extends StatefulWidget {
  const _DelayedBar(
      {required this.value, required this.color, required this.delay, this.height = 10, this.track, this.flat = false});
  final double value;
  final Color color;
  final Duration delay;
  final double height;
  final Color? track;
  final bool flat;

  @override
  State<_DelayedBar> createState() => _DelayedBarState();
}

class _DelayedBarState extends State<_DelayedBar> {
  bool _go = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _go = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _go ? widget.value.clamp(0, 1) : 0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          children: [
            Container(height: widget.height, color: widget.track ?? widget.color.withValues(alpha: 0.12)),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.flat ? widget.color : null,
                  gradient: widget.flat ? null : LinearGradient(colors: [widget.color.withValues(alpha: 0.75), widget.color]),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


const ruleTeal = Color(0xFF0F6E62);
const ruleTealSoft = Color(0xFFD5ECE7);


class RulePointRow extends StatelessWidget {
  const RulePointRow({super.key, required this.item, this.delay = Duration.zero});
  final RuleItem item;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F7),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Text('${item.points}/${item.max}점', style: const TextStyle(fontSize: 14.5, color: AppColors.text)),
        ]),
        const SizedBox(height: 8),
        _DelayedBar(value: item.fraction, color: ruleTeal, delay: delay, height: 4, track: ruleTealSoft, flat: true),
        const SizedBox(height: 10),
        Text(item.reason, style: const TextStyle(fontSize: 14, color: AppColors.text)),
      ]),
    );
  }
}


class RulePointsMini extends StatelessWidget {
  const RulePointsMini({super.key, required this.items});
  final List<RuleItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(
              width: 40,
              child: Text(items[i].label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtext)),
            ),
            Expanded(
              child: _DelayedBar(
                  value: items[i].fraction,
                  color: ruleTeal,
                  delay: Duration(milliseconds: 100 + i * 100),
                  height: 6,
                  track: ruleTealSoft),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text('${items[i].points}/${items[i].max}',
                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
    ]);
  }
}
