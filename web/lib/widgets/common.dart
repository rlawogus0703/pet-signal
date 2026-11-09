import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../matching/normalizer.dart';
import '../theme/app_theme.dart';

/// 품종별 기본 사진 (API 공고에 사진이 없을 때)
const _breedFallback = <String, String>{
  'maltese': 'assets/dogs/maltese_white.jpg',
  'mix': 'assets/dogs/mix_cream.jpg',
  'poodle': 'assets/dogs/poodle_brown.jpg',
  'pomeranian': 'assets/dogs/pomeranian.jpg',
  'shih_tzu': 'assets/dogs/shihtzu.jpg',
  'chihuahua': 'assets/dogs/chihuahua_black.jpg',
  'jindo': 'assets/dogs/jindo_white.jpg',
  'retriever': 'assets/dogs/golden.jpg',
  'beagle': 'assets/dogs/beagle.jpg',
  'yorkie': 'assets/dogs/yorkie.jpg',
  'bichon': 'assets/dogs/bichon.jpg',
  'corgi': 'assets/dogs/corgi.jpg',
  'dachshund': 'assets/dogs/dachshund.jpg',
};

String? resolveDogAsset({String? noticeId, String? breed}) {
  if (noticeId != null && noticePhotoAssets.containsKey(noticeId)) return noticePhotoAssets[noticeId];
  if (breed != null) return _breedFallback[Normalizer.normBreed(breed)];
  return null;
}

/// 강아지 사진: 업로드 바이트 → 번들 에셋 → 네트워크 → 플레이스홀더 순
class DogPhoto extends StatelessWidget {
  const DogPhoto({
    super.key,
    this.bytes,
    this.asset,
    this.url,
    this.noticeId,
    this.breed,
    this.radius = 16,
    this.aspectRatio,
    this.heroTag,
  });

  final Uint8List? bytes;
  final String? asset;
  final String? url;
  final String? noticeId;
  final String? breed;
  final double radius;
  final double? aspectRatio;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    Widget img;
    final fallbackAsset = asset ?? resolveDogAsset(noticeId: noticeId, breed: breed);
    Widget fallback() => fallbackAsset != null
        ? Image.asset(fallbackAsset, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _PhotoPlaceholder())
        : const _PhotoPlaceholder();
    if (bytes != null) {
      img = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null && url!.startsWith('http')) {
      img = Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
    } else {
      img = fallback();
    }
    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(child: img),
    );
    if (aspectRatio != null) child = AspectRatio(aspectRatio: aspectRatio!, child: child);
    if (heroTag != null) child = Hero(tag: heroTag!, child: child);
    return child;
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.coralSoft, Color(0xFFFFF7F2)]),
      ),
      child: const Center(child: Icon(Icons.pets_rounded, size: 40, color: AppColors.coral)),
    );
  }
}

/// 웹 호버 시 살짝 떠오르는 카드
class HoverCard extends StatefulWidget {
  const HoverCard({super.key, required this.child, this.onTap, this.padding, this.radius = 20, this.color});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover && widget.onTap != null;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color ?? Colors.white,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: active ? AppColors.coral.withValues(alpha: 0.45) : AppColors.line),
          boxShadow: active ? AppShadows.hover : AppShadows.soft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.radius),
            onTap: widget.onTap,
            child: Padding(padding: widget.padding ?? EdgeInsets.zero, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// 원형 총점 링 (애니메이션)
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.value, this.size = 64, this.stroke = 6, this.label});
  final double value;
  final double size;
  final double stroke;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.score(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(v * 100).round()}',
                    style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: AppColors.text, height: 1)),
                if (label != null)
                  Text(label!, style: TextStyle(fontSize: size * 0.13, color: AppColors.subtext, height: 1.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 작은 일치 칩
class MatchChip extends StatelessWidget {
  const MatchChip({super.key, required this.label, this.icon, this.strong = false});
  final String label;
  final IconData? icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final fg = strong ? AppColors.coralDark : AppColors.navySoft;
    final bg = strong ? AppColors.coralSoft : const Color(0xFFF1F3F7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// "유사 후보" 안내 배너
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCE3A6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: '유사 후보', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(
                    text: compact
                        ? '입니다. 같은 강아지로 단정하지 않아요. 공고 원문과 사진을 꼭 확인하세요.'
                        : '입니다. 펫 시그널은 같은 강아지라고 단정하지 않아요. 최종 확인은 공고 원문·사진을 보고 보호자와 보호소가 직접 해 주세요.'),
              ]),
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF7C4A03), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 섹션 제목
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing, this.step});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int? step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (step != null) ...[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
            child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: const TextStyle(color: AppColors.subtext, fontSize: 13.5)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 반짝이는 로딩 스켈레톤
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: const [Color(0xFFF0ECE8), Color(0xFFFAF8F6), Color(0xFFF0ECE8)],
            ),
          ),
        );
      },
    );
  }
}

/// 빈 화면 / 오류 화면
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFDC2626) : AppColors.coral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: Gap.l),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Gap.s),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subtext)),
              if (actionLabel != null) ...[
                const SizedBox(height: Gap.l),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 페이지 최대 폭 + 여백
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1180, this.padding});
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = padding ?? EdgeInsets.symmetric(horizontal: w < 700 ? 16 : 32, vertical: w < 700 ? 16 : 28);
    return SingleChildScrollView(
      padding: pad,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// 브랜드 로고
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.light = false, this.size = 34});
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.coral, Color(0xFFFF9A6B)]),
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: Icon(Icons.pets_rounded, color: Colors.white, size: size * 0.55),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('펫 시그널',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.5,
                    letterSpacing: -0.4,
                    color: light ? Colors.white : AppColors.navy,
                    height: 1.1)),
            Text('Pet Signal',
                style: TextStyle(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w600,
                    color: light ? Colors.white70 : AppColors.subtext,
                    height: 1.1)),
          ],
        ),
      ],
    );
  }
}
