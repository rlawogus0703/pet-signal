import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'candidates_screen.dart';
import 'home_screen.dart';
import 'my_page_screen.dart';
import 'notifications_screen.dart';
import 'register_screen.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _items = [
  _NavItem('홈', Icons.home_outlined, Icons.home_rounded),
  _NavItem('실종견 등록', Icons.add_circle_outline_rounded, Icons.add_circle_rounded),
  _NavItem('유사 후보', Icons.manage_search_rounded, Icons.manage_search_rounded),
  _NavItem('알림', Icons.notifications_none_rounded, Icons.notifications_rounded),
  _NavItem('마이페이지', Icons.person_outline_rounded, Icons.person_rounded),
];

/// 반응형 앱 셸: 넓은 화면은 사이드 내비, 좁은 화면은 하단 내비
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  Widget _page(AppState s) {
    final Widget page = switch (s.tab) {
      0 => const HomeScreen(),
      1 => const RegisterScreen(),
      2 => const CandidatesScreen(),
      3 => const NotificationsScreen(),
      _ => const MyPageScreen(),
    };
    if (s.tab != 0 && !s.loggedIn) return const AuthScreen(embedded: true);
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey('${s.tab}-${s.loggedIn}-${s.useApi}'), child: _page(s)),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(state: s),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _TopBar(state: s, wide: true),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: PreferredSize(preferredSize: const Size.fromHeight(64), child: _TopBar(state: s, wide: false)),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: s.tab,
        height: 66,
        onDestinationSelected: s.goTab,
        destinations: [
          for (var i = 0; i < _items.length; i++)
            NavigationDestination(
              icon: _badge(s, i, Icon(_items[i].icon)),
              selectedIcon: _badge(s, i, Icon(_items[i].selectedIcon, color: AppColors.coral)),
              label: _items[i].label == '실종견 등록' ? '등록' : _items[i].label,
            ),
        ],
      ),
    );
  }

  static Widget _badge(AppState s, int i, Widget icon) {
    if (i != 3 || s.unread == 0) return icon;
    return Badge(label: Text('${s.unread}'), backgroundColor: AppColors.coral, child: icon);
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.only(left: 8), child: BrandLogo()),
          const SizedBox(height: 32),
          for (var i = 0; i < _items.length; i++) ...[
            _SideNavTile(
              item: _items[i],
              selected: state.tab == i,
              badge: i == 3 ? state.unread : 0,
              onTap: () => state.goTab(i),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('2026 한국디지털콘텐츠학회', style: TextStyle(fontSize: 11.5, color: AppColors.subtext)),
                SizedBox(height: 2),
                Text('추계종합학술대회 · 10조', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavTile extends StatefulWidget {
  const _SideNavTile({required this.item, required this.selected, required this.onTap, this.badge = 0});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  State<_SideNavTile> createState() => _SideNavTileState();
}

class _SideNavTileState extends State<_SideNavTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.coralSoft : (_hover ? AppColors.bg : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(sel ? widget.item.selectedIcon : widget.item.icon,
                  color: sel ? AppColors.coral : AppColors.subtext, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.item.label,
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? AppColors.coralDark : AppColors.text,
                        fontSize: 14.5)),
              ),
              if (widget.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(99)),
                  child: Text('${widget.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.wide});
  final AppState state;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 14),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (!wide) const BrandLogo(size: 30) else Text(_items[state.tab].label, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          _ModeButton(state: state, compact: !wide),
          const SizedBox(width: 10),
          if (state.loggedIn)
            PopupMenuButton<String>(
              tooltip: '내 계정',
              position: PopupMenuPosition.under,
              onSelected: (v) {
                if (v == 'my') state.goTab(4);
                if (v == 'logout') state.logout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'my', child: Text('마이페이지')),
                PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              ],
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.navy,
                    child: Text(state.displayName.characters.first,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 8),
                    Text('${state.displayName}님', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.expand_more_rounded, size: 18),
                  ],
                ],
              ),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => state.goTab(1),
              child: const Text('로그인'),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.state, required this.compact});
  final AppState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final api = state.useApi;
    final color = api ? AppColors.success : AppColors.info;
    return Tooltip(
      message: '데이터 모드 변경 (Mock / API 서버)',
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => showDialog<void>(context: context, builder: (_) => ModeDialog(state: state)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(compact ? (api ? 'API' : 'Mock') : (api ? 'API 서버 연결' : 'Mock 시연 모드'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class ModeDialog extends StatefulWidget {
  const ModeDialog({super.key, required this.state});
  final AppState state;

  @override
  State<ModeDialog> createState() => _ModeDialogState();
}

class _ModeDialogState extends State<ModeDialog> {
  late bool _api = widget.state.useApi;
  late final _url = TextEditingController(text: widget.state.apiBaseUrl);

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('데이터 모드'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Mock (오프라인)'), icon: Icon(Icons.offline_bolt_outlined)),
                ButtonSegment(value: true, label: Text('API 서버'), icon: Icon(Icons.dns_outlined)),
              ],
              selected: {_api},
              onSelectionChanged: (v) => setState(() => _api = v.first),
            ),
            const SizedBox(height: 16),
            if (_api)
              TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: '서버 주소', hintText: 'http://127.0.0.1:8000'),
              )
            else
              const Text('서버 없이 예시 공고 16건과 웹 내장 매칭 엔진으로 동작해요. 학회 시연에 가장 안전한 모드예요.',
                  style: TextStyle(color: AppColors.subtext)),
            const SizedBox(height: 12),
            const Text('모드를 바꾸면 로그인이 초기화돼요.', style: TextStyle(fontSize: 12.5, color: AppColors.subtext)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          onPressed: () {
            widget.state.setMode(api: _api, baseUrl: _url.text);
            Navigator.pop(context);
          },
          child: const Text('적용'),
        ),
      ],
    );
  }
}
