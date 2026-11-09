import 'package:flutter/material.dart';

/// 등록 폼 선택지 (드롭다운 + 직접 입력 허용)
const breedOptions = <String>[
  '말티즈', '믹스견', '푸들', '토이푸들', '포메라니안', '비숑프리제', '시츄', '치와와', '요크셔테리어',
  '진돗개', '골든리트리버', '비글', '웰시코기', '닥스훈트', '프렌치불독', '코카스파니엘',
];

class ColorOption {
  const ColorOption(this.label, this.color);
  final String label;
  final Color color;
}

const colorOptions = <ColorOption>[
  ColorOption('흰색', Color(0xFFFFFFFF)),
  ColorOption('크림색', Color(0xFFF3E5C8)),
  ColorOption('황색', Color(0xFFE2B866)),
  ColorOption('갈색', Color(0xFF9A6B45)),
  ColorOption('검정', Color(0xFF23262E)),
  ColorOption('회색', Color(0xFF9CA3AF)),
  ColorOption('삼색', Color(0xFFC08A5B)),
  ColorOption('얼룩', Color(0xFFD6CFC7)),
];

class Region {
  const Region(this.sido, this.sigungu, this.lat, this.lng);
  final String sido;
  final String sigungu;
  final double lat;
  final double lng;
  String get label => '$sido $sigungu';
}

/// 시·군·구 중심 좌표 (거리 점수 계산용, 시연 기준)
const regions = <Region>[
  Region('경기도', '오산시', 37.1499, 127.0773),
  Region('경기도', '화성시', 37.1995, 126.8312),
  Region('경기도', '수원시', 37.2636, 127.0286),
  Region('경기도', '평택시', 36.9921, 127.1129),
  Region('경기도', '용인시', 37.2411, 127.1776),
  Region('경기도', '성남시', 37.4201, 127.1265),
  Region('경기도', '안양시', 37.3943, 126.9568),
  Region('경기도', '안성시', 37.0080, 127.2797),
  Region('경기도', '고양시', 37.6584, 126.8320),
  Region('서울특별시', '강남구', 37.5172, 127.0473),
  Region('서울특별시', '관악구', 37.4784, 126.9516),
  Region('서울특별시', '마포구', 37.5663, 126.9019),
  Region('서울특별시', '송파구', 37.5145, 127.1059),
  Region('서울특별시', '중구', 37.5640, 126.9970),
  Region('서울특별시', '종로구', 37.5735, 126.9790),
];

List<String> get sidoList => regions.map((r) => r.sido).toSet().toList();
