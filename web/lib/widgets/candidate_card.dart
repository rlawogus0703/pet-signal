import 'package:flutter/material.dart';

import '../matching/explain.dart';
import '../models/candidate.dart';
import '../models/lost_dog.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'common.dart';

/// 유사 후보 카드 (사진 + 총점 링 + 일치 칩)
class CandidateCard extends StatelessWidget {
  const CandidateCard({super.key, required this.candidate, required this.dog, required this.onTap, required this.rank});
  final Candidate candidate;
  final LostDog dog;
  final VoidCallback onTap;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final s = c.score;
    final km = distanceKm(dog, c);
    final dd = dayDiff(dog, c);
    final chips = <Widget>[
      if (s.breed >= 0.99) const MatchChip(label: '품종 일치', icon: Icons.check_rounded, strong: true)
      else if (s.breed >= 0.5) const MatchChip(label: '품종 보정', icon: Icons.sync_alt_rounded),
      if (s.color >= 0.99) const MatchChip(label: '색상 일치', icon: Icons.check_rounded, strong: true)
      else if (s.color >= 0.5) const MatchChip(label: '비슷한 색상', icon: Icons.sync_alt_rounded),
      if (km != null) MatchChip(label: km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km', icon: Icons.place_outlined, strong: km <= 10),
      MatchChip(label: dd >= 0 ? '실종 $dd일 후' : '실종 ${-dd}일 전', icon: Icons.event_outlined, strong: dd >= 0 && dd <= 7),
      if ((s.image ?? 0) >= 0.7) const MatchChip(label: '사진 유사', icon: Icons.auto_awesome_rounded),
    ];
    return HoverCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DogPhoto(
                  url: c.photoUrl,
                  noticeId: c.noticeId,
                  breed: c.breed,
                  radius: 0,
                  heroTag: 'photo-${dog.id}-${c.noticeId}',
                ),
              ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: rank <= 3 ? AppColors.coral : AppColors.navy,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$rank위', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
              Positioned(
                right: 12,
                bottom: -0,
                child: Transform.translate(
                  offset: const Offset(0, 28),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppShadows.soft),
                    child: ScoreRing(value: s.total, size: 60, stroke: 5.5, label: '유사도'),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 70),
                  child: Text('${c.color} ${c.breed}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 70),
                  child: Text('${c.age ?? '나이 미상'} · ${ymd(c.foundDate)} 발견',
                      style: const TextStyle(color: AppColors.subtext, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.subtext),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(c.foundAddress,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.home_work_outlined, size: 15, color: AppColors.subtext),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(c.shelterName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.subtext)),
                  ),
                  const Text('추천 이유 보기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.coralDark)),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.coralDark),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CandidateCardSkeleton extends StatelessWidget {
  const CandidateCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 4 / 3, child: Skeleton(radius: 0)),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 140, height: 18),
              SizedBox(height: 8),
              Skeleton(width: 180),
              SizedBox(height: 14),
              Row(children: [Skeleton(width: 64, height: 24, radius: 99), SizedBox(width: 6), Skeleton(width: 64, height: 24, radius: 99)]),
              SizedBox(height: 14),
              Skeleton(height: 12),
            ]),
          ),
        ],
      ),
    );
  }
}
