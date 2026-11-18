import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageBody(
      children: [
        _Hero(),
        SizedBox(height: Gap.xxl),
        SectionTitle('이렇게 이용해요', subtitle: '등록부터 보호소 연락까지, 세 단계면 충분해요.'),
        SizedBox(height: Gap.m),
        _SimpleSteps(),
        SizedBox(height: Gap.xl),
        _AboutLink(),
        SizedBox(height: Gap.xl),
        _Footer(),
      ],
    );
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
          '전국 보호소 공고에서 잃어버린 아이와 가장 비슷한 후보를 먼저 보여드려요.',
          style: TextStyle(color: Color(0xFFC9D2E3), fontSize: 16, height: 1.65),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => s.goTab(2),
              icon: const Icon(Icons.add_rounded),
              label: const Text('실종견 등록하기'),
            ),
            OutlinedButton.icon(
              onPressed: () => s.goTab(1),
              icon: const Icon(Icons.holiday_village_outlined),
              label: const Text('근처 공고 둘러보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                iconColor: Colors.white,
              ),
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

class _SimpleSteps extends StatelessWidget {
  const _SimpleSteps();

  static const _steps = [
    (1, Icons.edit_note_rounded, '실종견 등록하기', '사진, 품종, 색상, 실종 날짜와 위치를 알려주세요. 사진은 없어도 돼요.'),
    (2, Icons.manage_search_rounded, '비슷한 공고 확인하기', '닮은 후보를 비슷한 순서대로 보여드려요.'),
    (3, Icons.call_rounded, '보호소에 연락하기', '왜 닮았는지와 보호소 연락처를 확인하고 연락해요.'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 760 ? 1 : 3;
      const gap = 16.0;
      final itemW = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (n, icon, title, desc) in _steps)
            SizedBox(
              width: itemW,
              child: HoverCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(10)),
                        child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.coral)),
                      ),
                      const Spacer(),
                      Icon(icon, color: AppColors.navy),
                    ]),
                    const SizedBox(height: 12),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(desc, style: const TextStyle(color: AppColors.subtext, fontSize: 13.5, height: 1.5)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Center(
      child: TextButton.icon(
        onPressed: s.openAbout,
        icon: const Icon(Icons.info_outline_rounded, size: 18),
        label: const Text('서비스 소개 보기'),
      ),
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
        '펫 시그널은 “유사 후보”를 제안할 뿐 같은 개체로 단정하지 않습니다. 공고 원문과 사진은 보호자·보호소가 직접 확인해 주세요.',
        style: TextStyle(fontSize: 12, color: AppColors.subtext, height: 1.6),
        textAlign: TextAlign.center,
      ),
    );
  }
}
