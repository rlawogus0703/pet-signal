import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/demo.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.user!;
    final dogs = s.myDogs;
    return PageBody(
      maxWidth: 980,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.soft,
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.navy,
              child: Text(s.displayName.characters.first,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.displayName}님', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(u.email, style: const TextStyle(color: AppColors.subtext)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  MatchChip(label: s.useApi ? 'API 서버 계정' : 'Mock 시연 계정', icon: Icons.verified_user_outlined),
                  MatchChip(label: '가입 ${ymd(u.createdAt)}', icon: Icons.calendar_today_outlined),
                  if (u.phone != null && u.phone!.isNotEmpty) MatchChip(label: u.phone!, icon: Icons.phone_outlined),
                ]),
              ]),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃할까요?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('로그아웃')),
                    ],
                  ),
                );
                if (ok == true) await s.logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('로그아웃'),
            ),
          ]),
        ),
        const SizedBox(height: Gap.l),
        SectionTitle('내가 등록한 실종견',
            subtitle: '${dogs.length}마리 등록됨',
            trailing: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => s.goTab(1),
              icon: const Icon(Icons.add_rounded),
              label: const Text('추가 등록'),
            )),
        const SizedBox(height: Gap.m),
        if (dogs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            child: StateView(
              icon: Icons.pets_rounded,
              title: '등록한 실종견이 없어요',
              message: '논문 예시(흰색 말티즈, 오산시)로 바로 체험해 볼 수 있어요.',
              actionLabel: '예시로 체험하기',
              onAction: () => startDemo(context),
            ),
          )
        else
          for (final d in dogs) ...[
            HoverCard(
              padding: const EdgeInsets.all(16),
              onTap: () {
                s.selectDog(d.dog.id);
                s.goTab(2);
              },
              child: Row(children: [
                SizedBox(
                    width: 84,
                    height: 84,
                    child: DogPhoto(bytes: d.photoBytes, asset: d.photoAsset, breed: d.dog.breed, radius: 16)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(width: 8),
                      if (s.selectedDog?.dog.id == d.dog.id) const MatchChip(label: '선택됨', strong: true),
                    ]),
                    const SizedBox(height: 2),
                    Text('${d.dog.color} ${d.dog.breed}${d.dog.age != null ? ' · ${d.dog.age}' : ''}',
                        style: const TextStyle(color: AppColors.subtext)),
                    const SizedBox(height: 6),
                    Text('${ymd(d.dog.lostDate)} 실종 · ${d.dog.lostAddress}', style: const TextStyle(fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(children: [
                  TextButton.icon(
                    onPressed: () {
                      s.selectDog(d.dog.id);
                      s.goTab(2);
                    },
                    icon: const Icon(Icons.manage_search_rounded),
                    label: const Text('유사 후보'),
                  ),
                  IconButton(
                    tooltip: '목록에서 삭제',
                    onPressed: () => s.removeDog(d.dog.id),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.subtext),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
