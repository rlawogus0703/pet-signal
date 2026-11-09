import 'package:flutter/material.dart';

import '../matching/explain.dart';
import '../models/candidate.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/candidate_card.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

enum SortBy { score, distance, date }

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen> {
  Future<List<Candidate>>? _future;
  String? _loadedFor;
  SortBy _sort = SortBy.score;
  double? _maxKm;
  bool _recentOnly = false;

  void _load(AppState s, MyDog d, {bool force = false}) {
    if (!force && _loadedFor == d.dog.id && _future != null) return;
    _loadedFor = d.dog.id;
    _future = s.repo.getCandidates(d.dog.id, limit: 30);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final d = s.selectedDog;
    if (d == null) {
      return StateView(
        icon: Icons.manage_search_rounded,
        title: '아직 등록한 실종견이 없어요',
        message: '실종견을 등록하면 전국 보호소 공고 중 닮은 유사 후보를 순위대로 보여드려요.',
        actionLabel: '실종견 등록하기',
        onAction: () => s.goTab(1),
      );
    }
    _load(s, d);
    return FutureBuilder<List<Candidate>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        return PageBody(
          children: [
            _DogHeader(dog: d, state: s),
            const SizedBox(height: Gap.m),
            const DisclaimerBanner(),
            const SizedBox(height: Gap.l),
            _toolbar(snap.data),
            const SizedBox(height: Gap.m),
            if (loading)
              _grid(List.generate(6, (_) => const CandidateCardSkeleton()))
            else if (snap.hasError)
              StateView(
                icon: Icons.cloud_off_rounded,
                error: true,
                title: '후보를 불러오지 못했어요',
                message: '서버 연결을 확인해 주세요.\n${snap.error}',
                actionLabel: '다시 시도',
                onAction: () => setState(() => _load(s, d, force: true)),
              )
            else
              _results(s, d, snap.data ?? const []),
          ],
        );
      },
    );
  }

  List<Candidate> _apply(MyDog d, List<Candidate> list) {
    var out = list.where((c) {
      if (_maxKm != null) {
        final km = distanceKm(d.dog, c);
        if (km == null || km > _maxKm!) return false;
      }
      if (_recentOnly) {
        final dd = dayDiff(d.dog, c);
        if (dd < -1 || dd > 7) return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case SortBy.score:
        out.sort((a, b) => b.score.total.compareTo(a.score.total));
      case SortBy.distance:
        out.sort((a, b) => (distanceKm(d.dog, a) ?? 1e9).compareTo(distanceKm(d.dog, b) ?? 1e9));
      case SortBy.date:
        out.sort((a, b) => b.foundDate.compareTo(a.foundDate));
    }
    return out;
  }

  Widget _toolbar(List<Candidate>? data) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<SortBy>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: SortBy.score, label: Text('유사도순'), icon: Icon(Icons.star_outline_rounded, size: 18)),
            ButtonSegment(value: SortBy.distance, label: Text('가까운순'), icon: Icon(Icons.near_me_outlined, size: 18)),
            ButtonSegment(value: SortBy.date, label: Text('최근 발견순'), icon: Icon(Icons.schedule_rounded, size: 18)),
          ],
          selected: {_sort},
          onSelectionChanged: (v) => setState(() => _sort = v.first),
        ),
        for (final (label, v) in [('전체 거리', null), ('10km 이내', 10.0), ('30km 이내', 30.0)])
          ChoiceChip(
            label: Text(label),
            selected: _maxKm == v,
            onSelected: (_) => setState(() => _maxKm = v),
          ),
        FilterChip(
          label: const Text('실종 후 7일 이내'),
          selected: _recentOnly,
          onSelected: (v) => setState(() => _recentOnly = v),
        ),
      ],
    );
  }

  Widget _results(AppState s, MyDog d, List<Candidate> all) {
    final list = _apply(d, all);
    if (all.isEmpty) {
      return const StateView(
        icon: Icons.search_off_rounded,
        title: '아직 유사 후보가 없어요',
        message: '새로운 공고가 수집되면 알림으로 알려드릴게요.',
      );
    }
    if (list.isEmpty) {
      return StateView(
        icon: Icons.filter_alt_off_rounded,
        title: '조건에 맞는 후보가 없어요',
        message: '필터를 풀면 ${all.length}건의 후보를 볼 수 있어요.',
        actionLabel: '필터 초기화',
        onAction: () => setState(() {
          _maxKm = null;
          _recentOnly = false;
        }),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('유사 후보 ${list.length}건${list.length != all.length ? ' (전체 ${all.length}건)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.subtext)),
        const SizedBox(height: 12),
        _grid([
          for (var i = 0; i < list.length; i++)
            _FadeIn(
              delay: Duration(milliseconds: 40 * i.clamp(0, 12)),
              child: CandidateCard(
                candidate: list[i],
                dog: d.dog,
                rank: all.indexOf(list[i]) + 1,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DetailScreen(myDog: d, noticeId: list[i].noticeId, preview: list[i]),
                )),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 340).floor().clamp(1, 4);
      const gap = 18.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap + 6,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class _DogHeader extends StatelessWidget {
  const _DogHeader({required this.dog, required this.state});
  final MyDog dog;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final d = dog.dog;
    final dogs = state.myDogs;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.navy, Color(0xFF263B66)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: narrow ? 72 : 96,
            height: narrow ? 72 : 96,
            child: DogPhoto(bytes: dog.photoBytes, asset: dog.photoAsset, breed: d.breed, radius: 18),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내가 찾는 강아지', style: TextStyle(color: Color(0xFFC9D2E3), fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('${dog.name} · ${d.color} ${d.breed}',
                    style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(spacing: 14, runSpacing: 4, children: [
                  _meta(Icons.event_outlined, '${ymd(d.lostDate)} 실종'),
                  _meta(Icons.place_outlined, d.lostAddress),
                  if (d.age != null) _meta(Icons.cake_outlined, d.age!),
                ]),
              ],
            ),
          ),
          if (dogs.length > 1 && !narrow)
            PopupMenuButton<String>(
              tooltip: '다른 강아지 보기',
              onSelected: state.selectDog,
              itemBuilder: (_) => [
                for (final x in dogs)
                  PopupMenuItem(value: x.dog.id, child: Text('${x.name} · ${x.dog.color} ${x.dog.breed}')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('강아지 변경', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            )
        ],
      ),
    );
  }

  Widget _meta(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 15, color: const Color(0xFFC9D2E3)),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
      ]);
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay.inMilliseconds),
      curve: Interval(delay.inMilliseconds / (380 + delay.inMilliseconds), 1, curve: Curves.easeOut),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}
