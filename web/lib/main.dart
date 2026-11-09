import 'package:flutter/material.dart';

import 'screens/detail_screen.dart';
import 'screens/shell.dart';
import 'state/demo.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// 펫 시그널 웹 (10조 · 재현)
/// 기본: Mock 모드 (백엔드 없이 동작). 상단 모드 버튼으로 API 연동.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PetSignalApp(state: AppState()));
}

class PetSignalApp extends StatelessWidget {
  const PetSignalApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: '펫 시그널 — 실종견 유사 후보 매칭',
        theme: buildTheme(),
        debugShowCheckedModeBanner: false,
        home: const _Bootstrap(child: AppShell()),
      ),
    );
  }
}

/// URL 파라미터로 바로 시연 화면 열기
///   ?demo=1            데모 로그인 + 예시 실종견 등록 → 유사 후보
///   ?demo=1&tab=3      (0 홈, 1 등록, 2 후보, 3 알림, 4 마이페이지)
///   ?demo=1&detail=1   1위 후보 상세 화면
///   ?login=1&tab=1     데모 로그인만
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({required this.child});
  final Widget child;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final q = Uri.base.queryParameters;
    final s = AppScope.read(context);
    try {
      if (q['demo'] == '1') {
        await startDemo(context);
      } else if (q['login'] == '1') {
        await s.demoLogin();
      }
      final tab = int.tryParse(q['tab'] ?? '');
      if (tab != null) s.goTab(tab.clamp(0, 4));
      final d = s.selectedDog;
      if (q['detail'] != null && d != null && mounted) {
        final list = await s.repo.getCandidates(d.dog.id);
        final i = ((int.tryParse(q['detail']!) ?? 1) - 1).clamp(0, list.length - 1);
        if (!mounted || list.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DetailScreen(myDog: d, noticeId: list[i].noticeId, preview: list[i]),
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
