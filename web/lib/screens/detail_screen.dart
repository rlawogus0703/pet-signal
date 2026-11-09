import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../matching/explain.dart';
import '../matching/normalizer.dart';
import '../models/candidate.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/score_bar.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.myDog, required this.noticeId, this.preview});
  final MyDog myDog;
  final String noticeId;
  final Candidate? preview;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Future<Candidate>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.read(context).repo.getCandidateDetail(widget.myDog.dog.id, widget.noticeId);
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('링크를 열 수 없어요: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('추천 이유 상세'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: FutureBuilder<Candidate>(
        future: _future,
        builder: (context, snap) {
          final c = snap.data ?? widget.preview;
          if (c == null) {
            if (snap.hasError) {
              return StateView(
                icon: Icons.cloud_off_rounded,
                error: true,
                title: '상세 정보를 불러오지 못했어요',
                message: '${snap.error}',
                actionLabel: '다시 시도',
                onAction: () => setState(() => _future =
                    AppScope.read(context).repo.getCandidateDetail(widget.myDog.dog.id, widget.noticeId)),
              );
            }
            return const _DetailSkeleton();
          }
          return _content(c);
        },
      ),
    );
  }

  Widget _content(Candidate c) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final d = widget.myDog;
    final photo = AspectRatio(
      aspectRatio: wide ? 1 : 4 / 3,
      child: DogPhoto(
        url: c.photoUrl,
        noticeId: c.noticeId,
        breed: c.breed,
        radius: 24,
        heroTag: 'photo-${d.dog.id}-${c.noticeId}',
      ),
    );
    final summary = _summary(c);
    return PageBody(
      children: [
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: photo),
            const SizedBox(width: Gap.l),
            Expanded(flex: 6, child: summary),
          ])
        else ...[photo, const SizedBox(height: Gap.m), summary],
        const SizedBox(height: Gap.l),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _scores(c)),
            const SizedBox(width: Gap.l),
            Expanded(child: _reasons(c)),
          ])
        else ...[_scores(c), const SizedBox(height: Gap.m), _reasons(c)],
        const SizedBox(height: Gap.l),
        _comparison(c),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(24)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: child,
      );

  Widget _summary(Candidate c) {
    final km = distanceKm(widget.myDog.dog, c);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  MatchChip(label: '유사 후보 ${c.rank > 0 ? '${c.rank}위' : ''}', strong: true),
                  MatchChip(label: '공고 ${c.noticeNo}'),
                ]),
                const SizedBox(height: 12),
                Text('${c.color} ${c.breed}', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('${c.age ?? '나이 미상'} · ${c.features}', style: const TextStyle(color: AppColors.subtext)),
              ]),
            ),
            const SizedBox(width: 12),
            ScoreRing(
                value: c.score.total,
                size: MediaQuery.sizeOf(context).width < 700 ? 84 : 108,
                stroke: 8,
                label: '종합 유사도'),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          _info(Icons.event_outlined, '발견일', '${ymd(c.foundDate)} (실종 ${dayDiff(widget.myDog.dog, c)}일 후)'),
          _info(Icons.place_outlined, '발견 장소', '${c.foundAddress}${km != null ? '  ·  실종 위치에서 ${km.toStringAsFixed(1)}km' : ''}'),
          _info(Icons.home_work_outlined, '보호소', c.shelterName),
          _info(Icons.call_outlined, '연락처', c.shelterPhone),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: c.noticeUrl.isEmpty ? null : () => _open(c.noticeUrl),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('공고 원문 보기'),
            ),
            OutlinedButton.icon(
              onPressed: () => _open('tel:${c.shelterPhone.replaceAll('-', '')}'),
              icon: const Icon(Icons.call_rounded),
              label: const Text('보호소 전화'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${c.shelterName} ${c.shelterPhone} / 공고 ${c.noticeNo}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보호소 연락처를 복사했어요')));
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('연락처 복사'),
            ),
          ]),
          const SizedBox(height: 18),
          const DisclaimerBanner(compact: true),
        ],
      ),
    );
  }

  Widget _info(IconData i, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: AppColors.coral),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text(k, style: const TextStyle(color: AppColors.subtext))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _scores(Candidate c) {
    final items = scoreItems(c);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('항목별 유사도', subtitle: '규칙 점수 6개 + AI 멀티모달 점수 2개'),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++)
            ScoreBar(item: items[i], delay: Duration(milliseconds: 120 + i * 90)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              '종합 유사도 = 항목 점수 × 가중치의 합\n(품종 ${_w(items[0])} · 색상 ${_w(items[1])} · 거리 ${_w(items[2])} · 날짜 ${_w(items[3])} · 특징 ${_w(items[4])} · 나이 ${_w(items[5])} · 이미지 ${_w(items[6])} · 텍스트 ${_w(items[7])})',
              style: const TextStyle(fontSize: 12.5, color: AppColors.subtext, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  String _w(ScoreItem i) => '${(i.weight * 100).round()}%';

  Widget _reasons(Candidate c) {
    final ex = explain(widget.myDog.dog, c);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('추천 이유', subtitle: '왜 이 공고가 유사 후보인지 설명해 드려요'),
          const SizedBox(height: 16),
          for (final e in ex) _reasonTile(e),
          if (c.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('매칭 엔진 요약', style: TextStyle(fontSize: 12.5, color: AppColors.subtext, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final r in c.reasons) MatchChip(label: r.replaceAll('↔', '/'))]),
          ],
        ],
      ),
    );
  }

  Widget _reasonTile(Explanation e) {
    final color = switch (e.level) { 2 => AppColors.success, 1 => AppColors.warning, _ => const Color(0xFF94A3B8) };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(e.icon, size: 19, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(e.sentence, style: const TextStyle(color: AppColors.subtext, fontSize: 13.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _comparison(Candidate c) {
    final d = widget.myDog.dog;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final km = distanceKm(d, c);
    final rows = <(String, String, String, double)>[
      ('품종', d.breed, c.breed, c.score.breed),
      ('색상', d.color, c.color, c.score.color),
      ('나이', d.age ?? '-', c.age ?? '-', c.score.age),
      ('날짜', '${ymd(d.lostDate)} 실종', '${ymd(c.foundDate)} 발견', c.score.date),
      ('위치', d.lostAddress, '${c.foundAddress}${km != null ? ' (${km.toStringAsFixed(1)}km)' : ''}', c.score.distance),
      ('특징', d.features, c.features, c.score.features),
    ];
    Widget head(String title, Widget photo, String sub) => Expanded(
          child: Column(children: [
            SizedBox(height: narrow ? 120 : 180, width: narrow ? 120 : 180, child: photo),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(sub, style: const TextStyle(color: AppColors.subtext, fontSize: 12.5)),
          ]),
        );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('내 강아지 vs 후보 비교', subtitle: '정규화된 값 기준으로 항목마다 일치 정도를 표시해요'),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            head(widget.myDog.name,
                DogPhoto(bytes: widget.myDog.photoBytes, asset: widget.myDog.photoAsset, breed: d.breed, radius: 20),
                '보호자 등록 정보'),
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Icon(Icons.compare_arrows_rounded, color: AppColors.coral, size: 32),
            ),
            head('공고 ${c.noticeNo.split('-').last}',
                DogPhoto(url: c.photoUrl, noticeId: c.noticeId, breed: c.breed, radius: 20), c.shelterName),
          ]),
          const SizedBox(height: 20),
          for (final (k, a, b, v) in rows) _cmpRow(k, a, b, v, narrow),
          const SizedBox(height: 6),
          Text(
            '정규화 예: "${d.breed}" → ${Normalizer.normBreed(d.breed)}, "${c.breed}" → ${Normalizer.normBreed(c.breed)} / "${d.color}" → ${Normalizer.normColor(d.color)}, "${c.color}" → ${Normalizer.normColor(c.color)}',
            style: const TextStyle(fontSize: 12, color: AppColors.subtext),
          ),
        ],
      ),
    );
  }

  Widget _cmpRow(String k, String a, String b, double v, bool narrow) {
    final (icon, color, label) = v >= 0.99
        ? (Icons.check_circle_rounded, AppColors.success, '일치')
        : v >= 0.45
            ? (Icons.change_circle_rounded, AppColors.warning, '유사')
            : (Icons.remove_circle_outline_rounded, const Color(0xFF94A3B8), '다름');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: narrow ? 40 : 64, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: Text(a, style: const TextStyle(fontSize: 13.5))),
        SizedBox(
          width: narrow ? 56 : 80,
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5))),
      ]),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) {
    return const PageBody(children: [
      Skeleton(height: 320, radius: 24),
      SizedBox(height: 20),
      Skeleton(width: 240, height: 24),
      SizedBox(height: 12),
      Skeleton(height: 14),
      SizedBox(height: 8),
      Skeleton(height: 14),
    ]);
  }
}
