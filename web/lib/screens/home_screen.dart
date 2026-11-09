import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/demo.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 760;
    return PageBody(
      children: [
        const _Hero(),
        const SizedBox(height: Gap.l),
        const _Stats(),
        const SizedBox(height: Gap.xxl),
        const SectionTitle('왜 펫 시그널인가요?', subtitle: '보호자가 공고를 직접 찾을 때 생기는 세 가지 문제를 풀어요.'),
        const SizedBox(height: Gap.m),
        _Grid(narrow: narrow, children: const [
          _ProblemCard(Icons.refresh_rounded, '매일 반복되는 검색', '공고가 매일 새로 올라와 보호자가 같은 확인을 계속 반복해야 해요.',
              '서버가 공공데이터 API로 공고를 자동 수집하고, 새 후보가 생기면 알려드려요.'),
          _ProblemCard(Icons.map_outlined, '구조 장소 ≠ 실종 장소', '강아지가 다른 동네에서 구조되면 지역을 바꿔 가며 여러 번 찾아야 해요.',
              '실종 위치와의 실제 거리(km)로 점수를 매겨 지역 경계 없이 찾아요.'),
          _ProblemCard(Icons.translate_rounded, '서로 다른 표기', '“흰색 말티즈”가 공고에는 “크림색 믹스견”으로 올라오면 검색에서 빠져요.',
              '품종·색상 표기를 정규화하고 사진·문장 AI 유사도로 후보를 놓치지 않아요.'),
        ]),
        const SizedBox(height: Gap.xxl),
        const _NormalizationShowcase(),
        const SizedBox(height: Gap.xxl),
        const SectionTitle('이렇게 동작해요', subtitle: '등록부터 알림까지 4단계'),
        const SizedBox(height: Gap.m),
        _Grid(narrow: narrow, columns: 4, children: const [
          _StepCard(1, Icons.edit_note_rounded, '실종견 등록', '사진, 품종, 색상, 나이, 실종 날짜·위치, 특징을 입력해요.'),
          _StepCard(2, Icons.cloud_sync_rounded, '공고 자동 수집', '농림축산검역본부 구조동물 API를 주기적으로 받아 표기를 통일해요.'),
          _StepCard(3, Icons.auto_awesome_rounded, '멀티모달 매칭', '규칙 점수 + 이미지(CLIP)·텍스트 임베딩 유사도를 융합해요.'),
          _StepCard(4, Icons.notifications_active_rounded, '추천 이유·알림', '항목별 점수와 이유를 보여주고 새 후보를 알림으로 보내요.'),
        ]),
        const SizedBox(height: Gap.xxl),
        const _TechStack(),
        const SizedBox(height: Gap.xl),
        const _Footer(),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children, required this.narrow, this.columns = 3});
  final List<Widget> children;
  final bool narrow;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = narrow ? 1 : (c.maxWidth < 900 && columns > 2 ? 2 : columns);
      const gap = 16.0;
      final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: itemW, child: ch)],
      );
    });
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 1180;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white24),
          ),
          child: const Text('2026 한국디지털콘텐츠학회 추계종합학술대회 · 10조',
              style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 22),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '잃어버린 우리 아이,\n'),
            TextSpan(text: '닮은 공고', style: TextStyle(color: AppColors.coral.withValues(alpha: 1))),
            const TextSpan(text: '를 먼저 찾아드려요'),
          ]),
          style: TextStyle(
              color: Colors.white,
              fontSize: w < 700 ? 30 : 42,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -1),
        ),
        const SizedBox(height: 16),
        const Text(
          '펫 시그널은 전국 보호소 공고를 매일 자동으로 모아, 등록한 실종견과 닮은 유사 후보를 순위대로 보여주고, 품종·색상·거리·날짜·사진까지 어떤 점이 닮았는지 이유를 함께 알려드려요.',
          style: TextStyle(color: Color(0xFFC9D2E3), fontSize: 15.5, height: 1.65),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => s.goTab(1),
              icon: const Icon(Icons.add_rounded),
              label: const Text('실종견 등록하기'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38, width: 1.4),
              ),
              onPressed: () => startDemo(context),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('예시로 바로 체험하기'),
            ),
          ],
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(w < 700 ? 24 : 44),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF263B66)],
        ),
        boxShadow: AppShadows.hover,
      ),
      child: wide
          ? Row(children: [Expanded(flex: 6, child: text), const SizedBox(width: 32), const Expanded(flex: 4, child: _HeroVisual())])
          : text,
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 210,
            height: 260,
            child: _framed('assets/dogs/my_maltese.jpg', '내 강아지 · 흰색 말티즈'),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: 210,
            height: 260,
            child: _framed('assets/dogs/mix_cream.jpg', '보호소 공고 · 크림색 믹스견'),
          ),
          Positioned(
            left: 120,
            top: 140,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.hover,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScoreRing(value: 0.81, size: 46, stroke: 5),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('유사 후보 1순위', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text('색상 유사 · 6.4km · 1일 후', style: TextStyle(fontSize: 12, color: AppColors.subtext)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _framed(String asset, String caption) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: AppShadows.hover,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(asset, fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: const Color(0xAA16233F),
              child: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return _Grid(narrow: false, columns: narrow ? 2 : 4, children: const [
      _Stat('95,685', '마리', '2025년 전국 동물보호센터에\n입소한 유실·유기동물', '농림축산식품부 2025 실태조사'),
      _Stat('매일', '', '공공데이터 API로\n보호소 공고 자동 수집', '농림축산검역본부 구조동물 API'),
      _Stat('8', '개 항목', '품종·색상·거리·날짜·특징·나이\n+ 이미지·텍스트 AI 유사도', '멀티모달 융합 점수'),
      _Stat('Top 5', '', '상위 5개 후보 안에\n실제 강아지 포함 여부로 평가', '논문 평가 지표'),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.unit, this.label, this.source);
  final String value, unit, label, source;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.coral, letterSpacing: -0.8)),
            TextSpan(text: unit.isEmpty ? '' : ' $unit', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
          ])),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
          const SizedBox(height: 8),
          Text(source, style: const TextStyle(fontSize: 11.5, color: AppColors.subtext)),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard(this.icon, this.title, this.problem, this.solution);
  final IconData icon;
  final String title, problem, solution;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.coral),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(problem, style: const TextStyle(color: AppColors.subtext, fontSize: 13.5)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text(solution, style: const TextStyle(fontSize: 13.5, color: Color(0xFF166534)))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NormalizationShowcase extends StatelessWidget {
  const _NormalizationShowcase();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    Widget side(String asset, String who, String text) => Column(
          children: [
            SizedBox(width: 150, height: 150, child: DogPhoto(asset: asset, radius: 20)),
            const SizedBox(height: 10),
            Text(who, style: const TextStyle(color: AppColors.subtext, fontSize: 12.5)),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        );
    final compare = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _resultRow(false, '일반 조건 검색', '“말티즈” + “흰색” 필터 → 결과 없음'),
        const SizedBox(height: 10),
        _resultRow(true, '펫 시그널', '믹스견(소형)·흰색과 크림색을 같은 계열로 정규화 → 유사 후보 1위'),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('표기 정규화가 만드는 차이', subtitle: '논문 예시: 보호자는 “흰색 말티즈”, 보호소는 “크림색 믹스견”'),
          const SizedBox(height: 24),
          Flex(
            direction: narrow ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              side('assets/dogs/my_maltese.jpg', '보호자 등록', '흰색 말티즈'),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.compare_arrows_rounded, size: 36, color: AppColors.coral),
              ),
              side('assets/dogs/mix_cream.jpg', '보호소 공고', '크림색 믹스견'),
              const SizedBox(width: 32, height: 24),
              if (narrow) compare else Expanded(child: compare),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultRow(bool ok, String title, String desc) {
    final c = ok ? AppColors.success : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            Text(desc, style: const TextStyle(fontSize: 13.5)),
          ]),
        ),
      ]),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard(this.n, this.icon, this.title, this.desc);
  final int n;
  final IconData icon;
  final String title, desc;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('0$n', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFFE5DED8))),
            const Spacer(),
            Icon(icon, color: AppColors.navy),
          ]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: AppColors.subtext, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _TechStack extends StatelessWidget {
  const _TechStack();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Flutter', '웹·앱 클라이언트'),
      ('FastAPI', '매칭 API 서버'),
      ('PostgreSQL', '공고·매칭 DB'),
      ('공공데이터 API', '구조동물 공고 수집'),
      ('CLIP', '이미지 임베딩'),
      ('Sentence-Transformers', '문장 임베딩'),
      ('FCM', '신규 후보 푸시 알림'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('기술 구성'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (name, desc) in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                  TextSpan(text: '  $desc', style: const TextStyle(color: AppColors.subtext, fontSize: 13)),
                ])),
              ),
          ],
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '펫 시그널은 “유사 후보”를 제안할 뿐 같은 개체로 단정하지 않습니다. 시연용 공고·사진은 예시 데이터입니다 (사진: Wikimedia Commons).\n© 2026 10조 · 한신대학교',
        style: TextStyle(fontSize: 12, color: AppColors.subtext, height: 1.6),
      ),
    );
  }
}
