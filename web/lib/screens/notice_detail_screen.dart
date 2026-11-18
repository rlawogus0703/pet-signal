import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/browse_notice.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';


class NoticeDetailScreen extends StatelessWidget {
  const NoticeDetailScreen({super.key, required this.notice});
  final BrowseNotice notice;

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final n = notice;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('보호소 공고')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: DogPhoto(url: n.displayPhotoUrl, fallbackUrl: n.displayPhotoFallback, radius: 0),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${n.color} ${n.breed}'.trim(),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            [n.age, if (n.weight.isNotEmpty) n.weight, n.processState].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
            style: const TextStyle(color: AppColors.subtext, fontSize: 14),
          ),
          if (n.distKm != null) ...[
            const SizedBox(height: 6),
            Text('선택한 위치에서 ${n.distKm! < 10 ? n.distKm!.toStringAsFixed(1) : n.distKm!.round().toString()}km',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          _row(Icons.place_outlined, '발견 장소', n.foundAddress.isEmpty ? '-' : n.foundAddress),
          _row(Icons.event_outlined, '발견일', n.foundDate == null ? '-' : ymd(n.foundDate!)),
          _row(
            Icons.event_available_outlined,
            '공고 기간',
            '${n.noticeStart == null ? '-' : ymd(n.noticeStart!)} ~ ${n.noticeEnd == null ? '-' : ymd(n.noticeEnd!)}',
          ),
          _row(Icons.home_work_outlined, '보호소', n.shelterName.isEmpty ? '-' : n.shelterName),
          _row(Icons.pin_drop_outlined, '보호소 주소', n.shelterAddress.isEmpty ? '-' : n.shelterAddress),
          if (n.features.isNotEmpty) _row(Icons.notes_outlined, '특징', n.features),
          const SizedBox(height: 20),
          if (n.shelterPhone.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _open('tel:${n.shelterPhone}'),
              icon: const Icon(Icons.phone_rounded),
              label: Text('보호소에 전화 ${n.shelterPhone}'),
            ),
          if (n.noticeUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _open(n.noticeUrl),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('원문 공고 보기'),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '이 화면은 보호소 공고를 그대로 보여 드립니다. 동일 개체로 단정하지 말고, 보호소에 직접 확인해 주세요.',
            style: TextStyle(color: AppColors.subtext, fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.subtext),
          const SizedBox(width: 10),
          SizedBox(width: 88, child: Text(label, style: const TextStyle(color: AppColors.subtext))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
