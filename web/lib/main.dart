import 'package:flutter/material.dart';

import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';


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
    final about = (q['about'] ?? '').toLowerCase();
    if (about == '1' || about == 'true') s.openAbout();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
