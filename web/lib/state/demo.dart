import 'package:flutter/material.dart';

import 'app_state.dart';

/// 논문 예시 실종견 (흰색 말티즈, 한신대 근처 오산시 양산동)
class DemoDog {
  static const name = '콩이';
  static const breed = '말티즈';
  static const color = '흰색';
  static const age = '3살';
  static const features = '소형, 귀가 접힘, 빨간 목걸이, 왼쪽 귀 근처 점, 사람을 잘 따름';
  static const address = '경기도 오산시 양산동 (한신대학교 인근)';
  static const lat = 37.1934;
  static const lng = 127.0225;
  static final lostDate = DateTime(2026, 11, 1);
  static const photoAsset = 'assets/dogs/my_maltese.jpg';
}

/// 원클릭 시연: 데모 로그인 → 예시 실종견 등록 → 유사 후보 화면
Future<void> startDemo(BuildContext context) async {
  final s = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (!s.loggedIn) await s.demoLogin();
    final exists = s.myDogs.where((d) => d.name == DemoDog.name).toList();
    if (exists.isEmpty) {
      await s.registerDog(
        name: DemoDog.name,
        photoAsset: DemoDog.photoAsset,
        breed: DemoDog.breed,
        color: DemoDog.color,
        features: DemoDog.features,
        age: DemoDog.age,
        lostDate: DemoDog.lostDate,
        lostLat: DemoDog.lat,
        lostLng: DemoDog.lng,
        lostAddress: DemoDog.address,
      );
    } else {
      s.selectDog(exists.first.dog.id);
    }
    s.goTab(2);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('시연 시작 실패: $e')));
  }
}
