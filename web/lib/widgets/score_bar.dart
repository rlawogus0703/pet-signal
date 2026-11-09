import 'package:flutter/material.dart';

import '../matching/explain.dart';
import '../theme/app_theme.dart';

/// 항목별 점수 막대 (순차 애니메이션)
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.item, this.delay = Duration.zero});
  final ScoreItem item;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final v = item.value;
    final color = item.ai ? const Color(0xFF6366F1) : AppColors.score(v ?? 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(item.icon, size: 18, color: AppColors.subtext),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
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
            child: _DelayedBar(value: v ?? 0, color: color, delay: delay),
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
  const _DelayedBar({required this.value, required this.color, required this.delay});
  final double value;
  final Color color;
  final Duration delay;

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
            Container(height: 10, color: widget.color.withValues(alpha: 0.12)),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 10,
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
