import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 발표·학회용 서비스 소개: 통계, 문제/해결, 정규화 예시, 동작 방식, 시스템 구성도
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 760;
    return PageBody(
      children: [
        const _AboutHeader(),
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
          _StepCard(3, Icons.auto_awesome_rounded, '멀티모달 매칭', '텍스트 알고리즘·사진 유사도를 규칙 점수와 함께 멀티모달로 융합해요.'),
          _StepCard(4, Icons.notifications_active_rounded, '추천 이유·알림', '항목별 점수와 이유를 보여주고 새 후보를 알림으로 보내요.'),
        ]),
        const SizedBox(height: Gap.xxl),
        const SectionTitle('시스템 구성도', subtitle: '사용자 입력부터 실종견 매칭 추천까지, 펫 시그널의 AI 유사도 매칭 파이프라인'),
        const SizedBox(height: Gap.m),
        const SystemDiagram(),
        const SizedBox(height: Gap.xxl),
        const _TechStack(),
        const SizedBox(height: Gap.xl),
        const _Footer(),
      ],
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      padding: EdgeInsets.all(w < 700 ? 24 : 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, Color(0xFF263B66)],
        ),
        boxShadow: AppShadows.hover,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: s.closeAbout,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
            label: const Text('뒤로', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 18),
          Text(
            '서비스 소개',
            style: TextStyle(
              color: Colors.white,
              fontSize: w < 700 ? 28 : 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '펫 시그널은 전국 보호소 공고를 매일 자동으로 모아, 등록한 실종견과 닮은 유사 후보를 순위대로 보여주고, 품종·색상·거리·날짜·사진까지 어떤 점이 닮았는지 이유를 함께 알려드려요.',
            style: TextStyle(color: Color(0xFFC9D2E3), fontSize: 15.5, height: 1.65),
          ),
        ],
      ),
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

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return _Grid(narrow: false, columns: narrow ? 2 : 4, children: const [
      _Stat('95,685', '마리', '2025년 전국 동물보호센터에\n입소한 유실·유기동물', '농림축산식품부 2025 실태조사'),
      _Stat('매일', '', '공공데이터 API로\n보호소 공고 자동 수집', '농림축산검역본부 구조동물 API'),
      _Stat('3', '갈래', '텍스트 · 이미지 AI 유사도\n+ 규칙 점수(품종·색상·거리·날짜·나이)', '멀티모달 융합 점수'),
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

/// 시스템 구성도: 사용자 입력 → 실종견 DB + 공공데이터 API (Text/Image) → AI 유사도 매칭 → Multimodal → 매칭 추천
class SystemDiagram extends StatelessWidget {
  const SystemDiagram({super.key});

  static const _indigo = Color(0xFF6366F1);
  static const _sky = Color(0xFF0EA5E9);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      final stages = <Widget>[
        _stage(
          '01',
          '사용자 입력',
          Icons.edit_note_rounded,
          AppColors.navy,
          [
            _pill('나이'),
            _pill('지역'),
            _pill('이미지'),
            _pill('품종·색상·특징'),
          ],
        ),
        _stage(
          '02',
          '데이터',
          Icons.storage_rounded,
          AppColors.navy,
          [
            _box('실종견 DB', '보호자 등록 정보', Icons.pets_rounded, AppColors.navy),
            _box('공공데이터 API', '구조동물 공고 · 보호소 사진', Icons.cloud_download_outlined, AppColors.navy),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: _tag('Text 기반', _indigo)),
              const SizedBox(width: 6),
              Expanded(child: _tag('Image 기반', _sky)),
            ]),
          ],
        ),
        _stage(
          '03',
          'AI 유사도 매칭',
          Icons.auto_awesome_rounded,
          _indigo,
          [
            _box('텍스트 알고리즘', '키워드 · 문장 의미 · 속성/성향 분석', Icons.text_snippet_outlined, _indigo),
            _box('이미지 유사도', '사진 임베딩 (CLIP / 색상·형태 특징)', Icons.image_search_rounded, _sky),
            _box('규칙 점수', '품종 · 색상 · 거리 · 날짜 · 나이', Icons.rule_rounded, AppColors.subtext),
          ],
        ),
        _stage(
          '04',
          'Multimodal',
          Icons.hub_outlined,
          AppColors.coral,
          [
            _weight('규칙', 0.45, AppColors.navy),
            _weight('텍스트', 0.25, _indigo),
            _weight('이미지', 0.30, _sky),
            const SizedBox(height: 4),
            const Text('사진이 없으면 남은 갈래로 다시 계산',
                style: TextStyle(fontSize: 11.5, color: AppColors.subtext)),
          ],
        ),
        _stage(
          '05',
          '실종견 매칭 추천',
          Icons.recommend_rounded,
          AppColors.coral,
          [
            _box('유사 후보 순위', '최종 점수 높은 순', Icons.format_list_numbered_rounded, AppColors.coral),
            _box('추천 이유', '항목별 점수 · 공통 특징 · 사진 비교', Icons.lightbulb_outline_rounded, AppColors.coral),
            _box('신규 후보 알림', '새 공고가 들어오면 알림', Icons.notifications_active_outlined, AppColors.coral),
          ],
        ),
      ];
      final body = wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < stages.length; i++) ...[
                Expanded(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 340), child: stages[i])),
                if (i < stages.length - 1) const Padding(padding: EdgeInsets.only(top: 150), child: _Arrow(horizontal: true)),
              ],
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < stages.length; i++) ...[
                stages[i],
                if (i < stages.length - 1) const _Arrow(horizontal: false),
              ],
            ]);
      return Container(
        padding: EdgeInsets.all(wide ? 24 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: body,
      );
    });
  }

  Widget _stage(String no, String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: color == AppColors.subtext ? AppColors.text : color)),
            ),
            Text(no, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFCBD5E1))),
          ]),
          const SizedBox(height: 12),
          for (final ch in children) Padding(padding: const EdgeInsets.only(bottom: 6), child: ch),
        ],
      ),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.coral),
          const SizedBox(width: 6),
          Flexible(child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _box(String title, String sub, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: const [BoxShadow(color: Color(0x0A16233F), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 11.5, color: AppColors.subtext, height: 1.35)),
            ]),
          ),
        ]),
      );

  Widget _tag(String t, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _weight(String label, double w, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${(w * 100).round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: w / 0.45,
              minHeight: 7,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.horizontal});
  final bool horizontal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: horizontal ? const EdgeInsets.symmetric(horizontal: 4) : const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Icon(horizontal ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded,
              size: 20, color: const Color(0xFF94A3B8)),
        ),
      );
}
