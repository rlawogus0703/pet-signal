import 'package:flutter/material.dart';

import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// 펫 시그널 웹 (10조 · 재현)
/// 기본: Mock 모드. --dart-define=API_BASE_URL=... 로 빌드하면 API 모드로 시작.
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

/// URL 파라미터: ?tab=1 처럼 탭만 엽니다 (0 홈, 1 가까운 공고, 2 등록…).
/// 로그인·회원가입은 직접 해야 하며, 가까운 공고는 로그인 없이 볼 수 있어요.
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

  void _run() {
    final q = Uri.base.queryParameters;
    final s = AppScope.read(context);
    final tab = int.tryParse(q['tab'] ?? '');
    if (tab != null) s.goTab(tab.clamp(0, 5));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
