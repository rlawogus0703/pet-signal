import 'package:flutter/material.dart';

import '../matching/explain.dart';
import '../theme/app_theme.dart';

/// 항목별 점수 막대 (순차 애니메이션)
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
  const _DelayedBar({required this.value, required this.color, required this.delay, this.height = 10});
  final double value;
  final Color color;
  final Duration delay;
  final double height;

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
            Container(height: widget.height, color: widget.color.withValues(alpha: 0.12)),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.color.withValues(alpha: 0.75), widget.color]),
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


/// 교수님 구성도 세 갈래 막대: 텍스트 / 이미지 / 멀티모달 최종 (카드·상세 공용)
class BranchBars extends StatelessWidget {
  const BranchBars({super.key, required this.items, this.compact = false});
  final List<ScoreItem> items;
  final bool compact;

  static const colors = [Color(0xFF6366F1), Color(0xFF0EA5E9), AppColors.coral];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          compact
              ? _MiniBar(item: items[i], color: colors[i % colors.length], delay: Duration(milliseconds: 100 + i * 120))
              : ScoreBar(
                  item: items[i],
                  color: colors[i % colors.length],
                  labelWidth: 120,
                  delay: Duration(milliseconds: 100 + i * 120)),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.item, required this.color, required this.delay});
  final ScoreItem item;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final v = item.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 78,
          child: Text(item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtext)),
        ),
        Expanded(
          child: v == null
              ? Text(item.note ?? '-', style: const TextStyle(fontSize: 11.5, color: AppColors.subtext))
              : SizedBox(height: 7, child: _DelayedBar(value: v, color: color, delay: delay, height: 7)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 26,
          child: Text(v == null ? '-' : '${(v * 100).round()}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
