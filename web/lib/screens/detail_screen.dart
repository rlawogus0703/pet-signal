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
    final photo = _photoPair(c, wide);
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
        _scores(c),
        const SizedBox(height: Gap.l),
        _comparison(c),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  /// 내 사진 ↔ 보호소 공고 사진 나란히 (사진 유사도는 계산하지 않아요)
  Widget _photoPair(Candidate c, bool wide) {
    final d = widget.myDog;
    Widget labeled(Widget photo, String label) => Stack(children: [
          Positioned.fill(child: photo),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xCC16233F), borderRadius: BorderRadius.circular(99)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ]);
    final mine = labeled(
        DogPhoto(bytes: d.photoBytes, asset: d.photoAsset, radius: 20), '내 강아지 · ${d.name}');
    final shelter = labeled(
        DogPhoto(
          url: c.displayPhotoUrl,
          fallbackUrl: c.photo2ProxyUrl ?? c.photoUrl2,
          noticeId: c.noticeId,
          breed: c.source == 'seed' ? c.breed : null,
          radius: 20,
          heroTag: 'photo-${d.dog.id}-${c.noticeId}',
        ),
        c.source == 'seed' ? '예시 공고 사진' : '보호소 공고 사진');
    return AspectRatio(
      aspectRatio: wide ? 1.1 : 1.6,
      child: Stack(alignment: Alignment.center, children: [
        Row(children: [
          Expanded(child: mine),
          const SizedBox(width: 10),
          Expanded(child: shelter),
        ]),
      ]),
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
    final dd = dayDiff(widget.myDog.dog, c);
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
                value: c.score.displayPoints / 100,
                size: MediaQuery.sizeOf(context).width < 700 ? 84 : 108,
                stroke: 8,
                label: '규칙 점수'),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          _info(Icons.event_outlined, '구조 접수일', '${ymd(c.foundDate)} (${dd >= 0 ? '실종 $dd일 후' : '실종 ${-dd}일 전'})'),
          _info(Icons.place_outlined, '발견 장소', c.foundAddress),
          if (c.orgName.isNotEmpty) _info(Icons.account_balance_outlined, '관할', c.orgName),
          _info(Icons.home_work_outlined, '보호소', c.shelterName),
          if (c.shelterAddress.isNotEmpty) _info(Icons.map_outlined, '보호소 주소', c.shelterAddress),
          _info(Icons.call_outlined, '연락처', c.shelterPhone),
          if (c.noticeStart != null || c.noticeEnd != null)
            _info(Icons.date_range_outlined, '공고 기간',
                '${c.noticeStart == null ? '-' : ymd(c.noticeStart!)} ~ ${c.noticeEnd == null ? '-' : ymd(c.noticeEnd!)}'),
          if (c.weight.isNotEmpty || c.sex.isNotEmpty)
            _info(Icons.info_outline_rounded, '추가 정보', _extraInfo(c)),
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
          SizedBox(width: 82, child: Text(k, style: const TextStyle(color: AppColors.subtext))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  String _extraInfo(Candidate c) {
    final sex = switch (c.sex) { 'M' => '수컷', 'F' => '암컷', _ => '' };
    final neuter = switch (c.neuter) { 'Y' => '중성화 O', 'N' => '중성화 X', _ => '' };
    return [if (c.weight.isNotEmpty) c.weight, sex, neuter, if (c.processState.isNotEmpty) c.processState]
        .where((e) => e.isNotEmpty)
        .join(' · ');
  }

  /// 규칙 점수 100점 (김민재 앱 상세 화면과 같은 구성)
  Widget _scores(Candidate c) {
    final s = c.score;
    final items = ruleItemsOf(c);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('규칙 점수 ${s.displayPoints}/${s.maxPoints}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.2)),
          const SizedBox(height: 4),
          Text(s.caption, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 16),
          for (final (i, it) in items.indexed) RulePointRow(item: it, delay: Duration(milliseconds: 200 + i * 120)),
          if (items.isEmpty)
            const Text('항목별 점수를 아직 불러오지 못했어요. 잠시 뒤 다시 열어 주세요.',
                style: TextStyle(fontSize: 13.5, color: AppColors.subtext)),
          const SizedBox(height: 8),
          Text(s.note, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.55)),
          const SizedBox(height: 14),
          const Text('같은 강아지인지 사진과 공고 원문을 확인하고 보호소에 문의해 주세요.',
              style: TextStyle(fontSize: 14, color: AppColors.text, height: 1.55)),
        ],
      ),
    );
  }

  Widget _comparison(Candidate c) {
    final d = widget.myDog.dog;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    double f(String key) => c.score.item(key)?.fraction ?? 0;
    final rows = <(String, String, String, double)>[
      ('품종', d.breed, c.breed, f('breed')),
      ('색상', d.color, c.color, f('color')),
      ('지역', d.lostAddress, c.orgName.isNotEmpty ? '${c.orgName} · ${c.foundAddress}' : c.foundAddress, f('region')),
      ('특징', d.features, c.features.isEmpty ? '-' : c.features, f('features')),
      ('날짜', '${ymd(d.lostDate)} 실종', '${ymd(c.foundDate)} 접수', f('date')),
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
          const SectionTitle('내 강아지 vs 후보 비교', subtitle: '규칙 점수 항목마다 일치 여부를 표시해요'),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            head(widget.myDog.name,
                DogPhoto(bytes: widget.myDog.photoBytes, asset: widget.myDog.photoAsset, radius: 20),
                '보호자 등록 정보'),
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Icon(Icons.compare_arrows_rounded, color: AppColors.coral, size: 32),
            ),
            head('공고 ${c.noticeNo.split('-').last}',
                DogPhoto(url: c.displayPhotoUrl, fallbackUrl: c.photo2ProxyUrl ?? c.photoUrl2, noticeId: c.noticeId, breed: c.source == 'seed' ? c.breed : null, radius: 20),
                c.shelterName),
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
