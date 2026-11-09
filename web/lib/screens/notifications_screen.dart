import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'detail_screen.dart';

class _Item {
  _Item(this.n, this.dog);
  AppNotification n;
  final MyDog dog;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<_Item>>? _future;
  List<_Item>? _items;
  bool _unreadOnly = false;

  Future<List<_Item>> _load(AppState s) async {
    final out = <_Item>[];
    for (final d in s.myDogs) {
      final list = await s.repo.getNotifications(d.dog.id);
      out.addAll(list.map((n) => _Item(n, d)));
    }
    out.sort((a, b) => b.n.createdAt.compareTo(a.n.createdAt));
    _items = out;
    return out;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(AppScope.read(context));
  }

  AppNotification _asRead(AppNotification n) => AppNotification(
      id: n.id, lostDogId: n.lostDogId, noticeId: n.noticeId, title: n.title, body: n.body, createdAt: n.createdAt, read: true);

  Future<void> _markRead(AppState s, _Item it) async {
    if (it.n.read) return;
    try {
      await s.repo.markNotificationRead(it.n.id);
      setState(() => it.n = _asRead(it.n));
      s.refreshUnread();
    } catch (_) {}
  }

  Future<void> _markAll(AppState s) async {
    for (final it in _items ?? <_Item>[]) {
      if (!it.n.read) {
        try {
          await s.repo.markNotificationRead(it.n.id);
          it.n = _asRead(it.n);
        } catch (_) {}
      }
    }
    setState(() {});
    s.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (s.myDogs.isEmpty) {
      return StateView(
        icon: Icons.notifications_none_rounded,
        title: '받은 알림이 없어요',
        message: '실종견을 등록하면 새로운 유사 후보가 올라올 때마다 알려드려요.',
        actionLabel: '실종견 등록하기',
        onAction: () => s.goTab(1),
      );
    }
    return FutureBuilder<List<_Item>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return PageBody(maxWidth: 820, children: [
            for (var i = 0; i < 4; i++) ...[
              const Row(children: [
                Skeleton(width: 56, height: 56, radius: 14),
                SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Skeleton(width: 200, height: 16),
                  SizedBox(height: 8),
                  Skeleton(height: 12),
                ])),
              ]),
              const SizedBox(height: 22),
            ],
          ]);
        }
        if (snap.hasError) {
          return StateView(
            icon: Icons.cloud_off_rounded,
            error: true,
            title: '알림을 불러오지 못했어요',
            message: '${snap.error}',
            actionLabel: '다시 시도',
            onAction: () => setState(() => _future = _load(s)),
          );
        }
        final all = _items ?? const <_Item>[];
        final list = _unreadOnly ? all.where((e) => !e.n.read).toList() : all;
        final unread = all.where((e) => !e.n.read).length;
        return PageBody(
          maxWidth: 820,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('신규 후보 알림', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(unread > 0 ? '읽지 않은 알림 $unread개' : '모든 알림을 확인했어요',
                      style: const TextStyle(color: AppColors.subtext)),
                ]),
              ),
              if (unread > 0)
                TextButton.icon(
                  onPressed: () => _markAll(s),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('모두 읽음'),
                ),
            ]),
            const SizedBox(height: Gap.m),
            Row(children: [
              ChoiceChip(label: const Text('전체'), selected: !_unreadOnly, onSelected: (_) => setState(() => _unreadOnly = false)),
              const SizedBox(width: 8),
              ChoiceChip(label: Text('안 읽음 $unread'), selected: _unreadOnly, onSelected: (_) => setState(() => _unreadOnly = true)),
            ]),
            const SizedBox(height: Gap.m),
            if (list.isEmpty)
              const StateView(icon: Icons.mark_email_read_outlined, title: '새 알림이 없어요', message: '새로운 유사 후보가 생기면 여기에 표시돼요.')
            else
              for (final it in list) ...[
                _tile(s, it),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: Gap.m),
            const Text('실서비스에서는 FCM 푸시 알림으로 앱/웹에 바로 전달돼요.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.subtext)),
          ],
        );
      },
    );
  }

  Widget _tile(AppState s, _Item it) {
    final n = it.n;
    return HoverCard(
      color: n.read ? Colors.white : const Color(0xFFFFF6F3),
      padding: const EdgeInsets.all(16),
      onTap: () async {
        await _markRead(s, it);
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(myDog: it.dog, noticeId: n.noticeId)));
      },
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          SizedBox(width: 60, height: 60, child: DogPhoto(noticeId: n.noticeId, radius: 14)),
          if (!n.read)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: AppColors.coral, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(n.title,
                    style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800, fontSize: 15)),
              ),
              Text(relativeTime(n.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.subtext)),
            ]),
            const SizedBox(height: 4),
            Text(n.body, style: const TextStyle(fontSize: 13.5, color: AppColors.subtext)),
            const SizedBox(height: 6),
            MatchChip(label: '${it.dog.name} · ${it.dog.dog.color} ${it.dog.dog.breed}', icon: Icons.pets_rounded),
          ]),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: AppColors.subtext),
      ]),
    );
  }
}
